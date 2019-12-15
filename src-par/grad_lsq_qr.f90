!***********************************************************************
!
subroutine grad_lsq_qr(fi,dfidxi,istage,d)
!
!***********************************************************************
!
!      Purpose:
!      Calculates cell-centered gradients using Least-Squares approach.
!
!      Description:
!      Uses QR decomposition of system matrix via Householder or via
!      Gramm-Schmidt.
!      QR decomposition is precomputed and R^(-1)*Q^T is stored in 
!      D array for every cell.
!
!      Arguments:
!
!      FI - dependent field variable
!      dFIdxi - cell centered gradient - a three component gradient vector.
!      ISTAGE - integer. If ISTAGE=1 calculates and stores only geometrical
!      parameters - a system matrix for least square problem at every cell. 
!      Usually it is called with ISTAGE=1 at the beggining of simulation.
!      If 2 it doesn't calculate system matrix, just RHS and solves system.
!      D - System matrix - or R^(-1)*Q^T from it's QR factorisation
!      XC,YC,ZC - coordinates of cell centers   
!
!      Example call:
!      CALL dFIdxi_LSTSQ_QR(U,dUdxi,2,D)
!
!***********************************************************************
!
  use types
  use parameters
  use geometry!, only:numCells,numInnerFaces,numBoundaryFaces,noc,owner,neighbour,ijl,ijr,xf,yf,zf,xc,yc,zc
  use matrix_module

  implicit none

  integer, parameter :: n=3, m=6  ! m is the number of neighbours, e.g. for structured 3D mesh it's 6

  integer, intent(in) :: istage
  real(dp), dimension(numTotal), intent(in)   :: fi
  real(dp), dimension(n,numPCells), intent(inout) :: dFidxi
  real(dp), dimension(n,m,numCells), intent(inout) :: D

  !
  !    Locals
  !
  integer ::  i,l,k,ijp,ijn,inp,iface

  integer, dimension(numCells) :: neighbour_index  

  real(dp), dimension(m,n) :: Dtmp
  real(dp), dimension(n,m) :: Dtmpt
  real(dp), dimension(m,numCells)   :: b


  !REAL(dp), DIMENSION(m,n) :: R
  !REAL(dp), DIMENSION(m,m) :: Q
  !REAL(dp), DIMENSION(n,n) :: R1
  !REAL(dp), DIMENSION(n,m) :: Q1t

  INTEGER :: INFO
  REAL(dp), DIMENSION(n) :: TAU
  INTEGER, DIMENSION(n) :: WORK
  REAL(dp), DIMENSION(m) :: v1,v2,v3
  REAL(dp), DIMENSION(m,m) :: H1,H2,H3,Ieye
  REAL(dp), DIMENSION(n,n) :: R
  REAL(dp), DIMENSION(m,m) :: Q

 
!**************************************************************************************************
  if(istage.eq.1) then
  ! Coefficient matrix - should be calculated only once 
!**************************************************************************************************
    Dtmp(:,:) = 0.0d0
    neighbour_index(:) = 0

  ! Inner faces:                                             
  do i=1,numInnerFaces                                                       
    ijp = owner(i)
    ijn = neighbour(i)

      neighbour_index(ijp) = neighbour_index(ijp) + 1 
      l = neighbour_index(ijp)
      D(1,l,ijp) = xc(ijn)-xc(ijp)
      D(2,l,ijp) = yc(ijn)-yc(ijp)
      D(3,l,ijp) = zc(ijn)-zc(ijp)
  
      neighbour_index(ijn) = neighbour_index(ijn) + 1 
      l = neighbour_index(ijn)   
      D(1,l,ijn) = xc(ijp)-xc(ijn)
      D(2,l,ijn) = yc(ijp)-yc(ijn)
      D(3,l,ijn) = zc(ijp)-zc(ijn)
                                                            
  enddo     

  ! Faces along O-C grid cuts
  do i=1,noc
    ijp = ijl(i)
    ijn = ijr(i)

      neighbour_index(ijp) = neighbour_index(ijp) + 1
      l = neighbour_index(ijp)
      D(1,l,ijp) = xc(ijn)-xc(ijp)
      D(2,l,ijp) = yc(ijn)-yc(ijp)
      D(3,l,ijp) = zc(ijn)-zc(ijp)

      neighbour_index(ijn) = neighbour_index(ijn) + 1 
      l = neighbour_index(ijn) 
      D(1,l,ijn) = xc(ijp)-xc(ijn)
      D(2,l,ijn) = yc(ijp)-yc(ijn)
      D(3,l,ijn) = zc(ijp)-zc(ijn)
      
  end do

  ! Faces on processor boundaries                                             
  do i=1,npro      
    iface = iProcFacesStart + i
    ijp = owner( iface )
    ijn = iProcStart + i

      neighbour_index(ijp) = neighbour_index(ijp) + 1
      l = neighbour_index(ijp)
      D(1,l,ijp) = xc(ijn)-xc(ijp)
      D(2,l,ijp) = yc(ijn)-yc(ijp)
      D(3,l,ijp) = zc(ijn)-zc(ijp)
      
  end do

  ! Boundary faces:

  ! Inlet: 
  do i=1,ninl
    iface = iInletFacesStart + i
    ijp = owner(iface)
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        D(1,l,ijp) = xf(iface)-xc(ijp)
        D(2,l,ijp) = yf(iface)-yc(ijp)
        D(3,l,ijp) = zf(iface)-zc(ijp)
  end do

  ! Outlet
  do i=1,nout
  iface = iOutletFacesStart + i
  ijp = owner(iface)
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        D(1,l,ijp) = xf(iface)-xc(ijp)
        D(2,l,ijp) = yf(iface)-yc(ijp)
        D(3,l,ijp) = zf(iface)-zc(ijp)
  end do

  ! Symmetry
  do i=1,nsym
  iface = iSymmetryFacesStart + i
  ijp = owner(iface)
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        D(1,l,ijp) = xf(iface)-xc(ijp)
        D(2,l,ijp) = yf(iface)-yc(ijp)
        D(3,l,ijp) = zf(iface)-zc(ijp)
  end do

  ! Wall
  do i=1,nwal
  iface = iWallFacesStart + i
  ijp = owner(iface)
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        D(1,l,ijp) = xf(iface)-xc(ijp)
        D(2,l,ijp) = yf(iface)-yc(ijp)
        D(3,l,ijp) = zf(iface)-zc(ijp)
  end do

  ! Pressure Outlet
  do i=1,npru
  iface = iPressOutletFacesStart + i
  ijp = owner(iface)
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        D(1,l,ijp) = xf(iface)-xc(ijp)
        D(2,l,ijp) = yf(iface)-yc(ijp)
        D(3,l,ijp) = zf(iface)-zc(ijp)
  end do

!--------------------------------------------------------------------------------------------------
  ! Form system matrix using QR decomposition:

  ! Cell loop

  do inp=1,numCells

  l = neighbour_index(inp)

  Dtmpt = D(:,:,inp)
  Dtmp = transpose(Dtmpt)

  !1 ...Decompose A=QR using Householder
  !      call householder_qr(Dtmp, m, n, Q, R)
  !2 ...Decompose A=QR using Gram-Schmidt
  !      call mgs_qr(Dtmp, m, n, Q, R)

  !      Q = transpose(Q)
  !      Q1t = Q(1:n,1:m)     ! NOTE: A=Q1R1 is so-called 'thin QR factorization' - see Golub & Van Loan
                              ! Here Q1 is actually Q1^T a transpose of Q1(thin Q - Q with m-n column stripped off)
  !      R1 = R(1:n,1:n)      ! our Q1 is thin transpose of original Q.
  !      R1 = inv(R1)         ! inv is a function in matrix_module, now works only for 3x3 matrices.
  !      Q1t  = matmul(R1,Q1t) ! this is actually R^(-1)*Q^T - a matrix of size n x m.
  !      D(:,:,INP) = Q1t     ! Store it for later.

  !3....LAPACK routine DGEQRF
  CALL DGEQRF( l, N, Dtmp, M, TAU, WORK, N, INFO )

  ! Upper triangular matrix R
  R(1:n,1:n)=Dtmp(1:n,1:n)

  ! Create reflectors
  !H(i) = I - TAU * v * v'
  Ieye=eye(l)
  !v(1:i-1) = 0. and v(i) = 1; v(i+1:m) is stored on exit in A(i+1:m,i)
  v1(1) = 1.; v1(2:l)=Dtmp(2:l,1)
  H1 = rank_one_update(Ieye,l,l,v1,v1,-TAU(1))
  v2(1) = 0.; v2(2) = 1.; v2(3:l)=Dtmp(3:l,2)
  H2 = rank_one_update(Ieye,l,l,v2,v2,-TAU(2))
  v3(1:2) = 0.; v3(3) = 1.; v3(4:l)=Dtmp(4:l,3)
  H3 = rank_one_update(Ieye,l,l,v3,v3,-TAU(3))
  ! The matrix Q is represented as a product of elementary reflectors H1, H2, ..., Hn
  Q=matmul(H1,H2)
  Q=matmul(Q,H3)

  ! Form R_1^(-1)*Q_1^T explicitely:
  do k=1,neighbour_index(inp)
    d(1,k,inp) = q(k,1)/r(1,1) - (r(1,2)*q(k,2))/(r(1,1)*r(2,2)) + (q(k,3)*(r(1,2)*r(2,3) - r(1,3)*r(2,2)))/(r(1,1)*r(2,2)*r(3,3))
    d(2,k,inp) = q(k,2)/r(2,2) - (r(2,3)*q(k,3))/(r(2,2)*r(3,3))
    d(3,k,inp) = q(k,3)/r(3,3)
  enddo

  enddo


!**************************************************************************************************
  elseif(istage.eq.2) then
!**************************************************************************************************
 

!--------------------------------------------------------------------------------------------------
  ! RHS vector
  b(:,:)=0.0d0

  neighbour_index(:) = 0

  ! Inner faces:                                             
  do i=1,numInnerFaces                                                       
    ijp = owner(i)
    ijn = neighbour(i)

        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        b(l,ijp) = fi(ijn)-fi(ijp)

        neighbour_index(ijn) = neighbour_index(ijn) + 1        
        l = neighbour_index(ijn)   
        b(l,ijn) = fi(ijp)-fi(ijn)
                                                                                                                   
  enddo     

  
  ! Faces along O-C grid cuts
  do i=1,noc
    ijp = ijl(i)
    ijn = ijr(i)

        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        b(l,ijp) = fi(ijn)-fi(ijp)

        neighbour_index(ijn) = neighbour_index(ijn) + 1        
        l = neighbour_index(ijn)   
        b(l,ijn) = fi(ijp)-fi(ijn)
 
  end do

  ! Faces on processor boundaries                                             
  do i=1,npro      
    iface = iProcFacesStart + i
    ijp = owner( iface )
    ijn = iProcStart + i

        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        b(l,ijp) = fi(ijn)-fi(ijp)
 
  end do

  ! Boundary faces:

  do i = 1,ninl
    iface = iInletFacesStart+i
    ijp = owner(iface)
    ijn = iInletStart + i
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        b(l,ijp) = fi(ijn)-fi(ijp)
  enddo

  do i = 1,nout
    iface = iOutletFacesStart+i
    ijp = owner(iface)
    ijn = iOutletStart + i
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        b(l,ijp) = fi(ijn)-fi(ijp)
  enddo

  do i = 1,nsym
    iface = iSymmetryFacesStart+i
    ijp = owner(iface)
    ijn = iSymmetryStart+i
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        b(l,ijp) = fi(ijn)-fi(ijp)
  enddo

  do i = 1,nwal
    iface = iWallFacesStart+i
    ijp = owner(iface)
    ijn = iWallStart+i
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        b(l,ijp) = fi(ijn)-fi(ijp)
  enddo

  do i=1,npru
    iface = iPressOutletFacesStart + i
    ijp = owner(iface)
    ijn = iPressOutletStart + i
        neighbour_index(ijp) = neighbour_index(ijp) + 1
        l = neighbour_index(ijp)
        b(l,ijp) = fi(ijn)-fi(ijp)
  enddo


!--------------------------------------------------------------------------------------------------

! Solve overdetermined system in least-sqare sense

  ! Cell loop
  do inp=1,numCells

    l = neighbour_index(inp)     

    !  ...using precomputed QR factorization and storing R^(-1)*Q^T in D
    dFIdxi(1,INP) = sum(D(1,1:l,inp)*b(1:l,inp))
    dFIdxi(2,INP) = sum(D(2,1:l,inp)*b(1:l,inp))
    dFIdxi(3,INP) = sum(D(3,1:l,inp)*b(1:l,inp))

  enddo


!**************************************************************************************************
  endif


end subroutine