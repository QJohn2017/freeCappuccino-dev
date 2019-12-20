module sparse_matrix
!
! Module defining CSR (Compressed Sparse Row) sparse matrix data type.
!
  use types
  use geometry, only: numCells,numInnerFaces,owner, neighbour
  use utils, only: csr_to_k, find_index_position, find_main_diag_element_positions, i4vec2_sort_a, i4vec_print, i4vec_print2

  ! Matrix in sparse format CSR(ioffset,ja,a) and COO(ia,ja,a)
  integer :: nnz                                ! no. of nonzeros in sparse system matrix
  integer, dimension(:), allocatable :: ioffset ! where in 'a' array, coefs for this matrix row start, size[1:ncell+1]
  integer, dimension(:), allocatable :: ia      ! Columns [1:nnz]
  integer, dimension(:), allocatable :: ja      ! Columns [1:nnz]
  integer, dimension(:), allocatable :: diag    ! Position of diagonal elements [1:ncell]
  real(dp), dimension(:), allocatable :: a      ! Coefficient matrix [1:nnz]

  integer, dimension(:), allocatable :: icell_jcell_csr_index !(i,j) matrix element transfered to a position in an array of length (1:nnz)
  integer, dimension(:), allocatable :: jcell_icell_csr_index !(j,i) matrix element transfered to a position in an array of length (1:nnz)

  ! Coefficients resulting form fvm discretization:
  real(dp), dimension(:), allocatable :: res           ! Residual vector for linear solvers
  real(dp), dimension(:), allocatable :: spu,spv,sp    ! Source terms for the left hand side
  real(dp), dimension(:), allocatable :: su, sv, sw    ! Source terms for the left hand side of equation
  real(dp), dimension(:), allocatable :: apu, apv, apw ! Reciprocal values of diagonal coefficients
  real(dp), dimension(:), allocatable :: rAu,rAv,rAw   ! Reciprocal values of diagonal coefficients containing only con. and diff. terms

  !
  ! The CSR matrix derived type
  !
  type csrMatrix
    integer, dimension(:), allocatable :: ioffset
    integer, dimension(:), allocatable :: ja
    integer, dimension(:), allocatable :: diag   
    real(dp), dimension(:), allocatable :: a
  end type


public

contains

!
! > Create new CSR matrix object for givenL nnz, numCells, ioffset and ja data arrays.
!
function new_csrMatrix( ) result(csr)
  implicit none
  integer :: i
  type(csrMatrix) :: csr
  

  ! Option 1.

  allocate(csr%ioffset ( numCells+1 ))
  allocate(csrx%ja ( nnz ))
  allocate(csr%diag ( numCells ))
  allocate(csr%a ( nnz ))

  do i=1,numCells+1
    csr % ioffset(i) = ioffset(i)
  enddo

  do i=1,numCells
    csr % diag(i) = diag(i)
  enddo
  
  do i=1,nnz
    csr % ja(i) = ja(i)
  enddo

  !
  ! Option 2. Instead of all this above - allocate on asignement
  !
  ! csr % ioffset = ioffset
  ! csr % diag = diag
  ! csr % ja = ja
  ! csr % a  = a
  

end function new_csrMatrix

!
! > Create new CSR matrix object for given mesh data.
!

subroutine create_CSR_matrix
!
! Define sparsity pattern according to given mesh connectivity data,
! and allocate arays representing system matrix in CSR format
!
  implicit none
  
  integer :: i
  integer :: icell,ijp,ijn
  integer :: istart, iend


  ! Number of non-zero elements in sparse matrix: nnz
  nnz = 2*numInnerFaces + numCells

  write ( *, '(a)' ) ' '
  write ( *, '(a,i0)' ) '  Number of nonzero coefficients in sparse matrix, nnz = ', nnz

  allocate ( ia(nnz) ) 
  allocate ( ja(nnz) )

  write ( *, '(a)' ) ' '
  write ( *, '(a,i0)' ) '  Creating CSR matrix sparsity pattern based on mesh data.'

!
!  > Populate sparsity arrays for CSR format
!

  ! This will be postions of diagonal elements, but later we'll sort ia,ja.
  do icell = 1,numCells
    ia(icell) = icell
    ja(icell) = icell
  enddo
  do i = 1,numInnerFaces
    ia(numCells+i) = owner(i)
    ja(numCells+i) = neighbour(i) 
  enddo
  do i = 1,numInnerFaces
    ia(numCells+numInnerFaces+i) = neighbour(i) 
    ja(numCells+numInnerFaces+i) = owner(i)
  enddo

!
!  > Lexically sort the ia, ja values.
!
  call i4vec2_sort_a ( nnz, ia, ja )

  ! call i4vec_print2 ( 10, ia, ja, '  First 10 lines of Sorted IA and JA arrays:' )


!
! > Find positions of diagonal elements in COO matrix format
!
 allocate ( diag(numCells) )

 call find_main_diag_element_positions ( ia,ja,nnz,diag,numCells )

 ! call i4vec_print ( 10, diag, '  First 20 lines of Diagonal adjacency vector:' )


!
! > Find positions of row starting in COO matrix format
!
 allocate ( ioffset(numCells+1) )

 istart = 1
 iend = 1
 do icell = 1,numCells
   call find_index_position(icell, istart, iend, ia,  nnz, ioffset(icell))
   istart = ioffset(icell)+1
   iend = nnz
 enddo
 ioffset(numCells+1) = nnz+1 ! poslednji element

 ! call i4vec_print ( 10, ioffset, '  First 10 lines of ioffset vector:' )


!
! > Do not need row indices - information on rows is in ioffset (CSR format)
!
  deallocate ( ia )

!
! > Allocate array representing system values in CSR format
!
  allocate( a(nnz) )

!
! > Source vectors
!
  allocate( su(numCells) ) 
  allocate( sv(numCells) )  
  allocate( sw(numCells)) 

! > Sources for main diagonal
!
  allocate( spu(numCells) )  
  allocate( spv(numCells) ) 
  allocate( sp(numCells) ) 

!
! > Residual vector
! 
  allocate(res(numCells) ) 

!
! > 1./UEqn.A()
!
  allocate(apu(numCells) )
  allocate(apv(numCells) ) 
  allocate(apw(numCells) ) 
  allocate(rAu(numCells) )
  allocate(rAv(numCells) )
  allocate(rAw(numCells) )

!
! > Allocate array storing indexes of 'a' array where cell pair coefs are stored
!
  allocate( icell_jcell_csr_index(numInnerFaces) )
  allocate( jcell_icell_csr_index(numInnerFaces) )

!
! >Index arrays of matrix elements stored in CSR format
!
  do i=1,numInnerFaces                                                       
    ijp = owner(i)
    ijn = neighbour(i)

    ! Index of the (icell,jcell) matrix element:
    icell_jcell_csr_index(i) = csr_to_k(ijp,ijn,ioffset,ja) 

    ! Index of the (jcell,icell) matrix element:
    jcell_icell_csr_index(i) = csr_to_k(ijn,ijp,ioffset,ja) 
  enddo

!+-----------------------------------------------------------------------------+

end subroutine create_CSR_matrix


end module sparse_matrix