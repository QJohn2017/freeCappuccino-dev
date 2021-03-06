module k_eqn_eddy
!
! Implementation of one-equation eddy viscosity SGS, 
! Yoshizawa et al. - Bridging between eddy-viscosity-type and second-order models using an two-scale DIA,
! 9th International symposium on turbulent shear flow, Kyoto, Japan, Vol. 3., 1993, p 23.1.1-23.1.6.
!
  use types
  use parameters
  use geometry
  use variables
  use scalar_fluxes, only: facefluxsc

  implicit none

  ! Turbulence model constants
  real(dp), parameter :: Ck = 0.094_dp
  real(dp), parameter :: Ceps = 1.048_dp

  ! Derived constants
  real(dp), parameter :: CMU25 = sqrt(sqrt(ck))
  real(dp), parameter :: CMU75 = cmu25**3


  private 

  public :: correct_turbulence_k_eqn_eddy
  public :: correct_turbulence_inlet_k_eqn_eddy


contains


subroutine correct_turbulence_k_eqn_eddy()
!
! Main module routine to solve turbulence model equations and update effective viscosity.
!
  use types
  use parameters
  use variables
  use gradients
  implicit none

  call calcsc(TE,dTEdxi,ite) ! Assemble and solve turbulence kinetic energy eq.
 
  call modify_mu_eff()       ! Update effective viscosity


end subroutine



subroutine correct_turbulence_inlet_k_eqn_eddy()
!
! Update turbulent and effective viscosity at inlet.
!
  use types
  use parameters
  use geometry, only:numBoundaries,nfaces,startFace,iBndValueStart,arx,ary,arz 
  use variables

  implicit none

  integer :: i,ib,ijb,iface
  real(dp) :: are, Delta

  !
  ! Boundary faces 
  !
  do ib=1,numBoundaries

    if ( bctype(ib) == 'inlet' ) then

      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijb = iBndValueStart(ib) + i

        are = sqrt( arx(iface)**2 + ary(iface)**2 + arz(iface)**2 )
        Delta = sqrt(are)

        ! Update effective viscosity:
        ! \mu_{eff}=\mu+\mu_t; \mu_t = C_k * k^{0.5} * Delta

        vis(ijb) = viscos + den(ijb)*ck*sqrt(te(ijb))*delta

      end do

    endif

  enddo 

end subroutine



subroutine calcsc(Fi,dFidxi,ifi)
!
!
!
  use types
  use parameters
  use geometry
  use variables
  use sparse_matrix
  use gradients
  use title_mod

  implicit none

  integer, intent(in) :: ifi
  real(dp), dimension(numTotal) :: fi
  real(dp), dimension(3,numCells) :: dfidxi

!
! Local variables
!
  integer ::  i, k, inp, ijp, ijn, ijb, ib, iface, iwall, ipro
  real(dp) :: gam, prtr, apotime, urfrs, urfms, &
              utp, vtp, wtp, utn, vtn, wtn, &
              genp, genn, &
              uttbuoy, vttbuoy, wttbuoy
  real(dp) :: cap, can, suadd
  ! real(dp) :: magStrainSq
  real(dp) :: off_diagonal_terms
  real(dp) :: are,nxf,nyf,nzf,vnp,xtp,ytp,ztp,ut2
  real(dp) :: dudx,dudy,dudz,dvdx,dvdy,dvdz,dwdx,dwdy,dwdz
  real(dp) :: viss
  real(dp) :: fimax,fimin
  real(dp) :: delta,third,three_halfs

  third = 1./3.0_dp
  three_halfs = 3./2.0_dp

  ! Variable specific coefficients:
  gam = gds(ifi)

  prtr = 1.0_dp

! Calculate gradient: 
  call grad(fi,dfidxi)

! Initialize coef and source arrays
  a = 0.0_dp
  su = 0.0_dp
  sp = 0.0_dp

!
! CALCULATE SOURCE TERMS INTEGRATED OVER VOLUME
!

  ! TKE volume source terms

  !=========================================================
  ! STANDARD PRODUCTION
  !=========================================================

  do inp=1,numCells

    dudx = dudxi(1,inp)
    dudy = dudxi(2,inp)
    dudz = dudxi(3,inp)

    dvdx = dvdxi(1,inp)
    dvdy = dvdxi(2,inp)
    dvdz = dvdxi(3,inp)

    dwdx = dwdxi(1,inp)
    dwdy = dwdxi(2,inp)
    dwdz = dwdxi(3,inp)

    ! Minus here in fron because UU,UV,... calculated in calcstress hold -tau_ij
    ! So the exact production is calculated as tau_ij*dui/dxj
    gen(inp) = -den(inp)*( uu(inp)*dudx+uv(inp)*(dudy+dvdx)+ &
                           uw(inp)*(dudz+dwdx)+vv(inp)*dvdy+ &
                           vw(inp)*(dvdz+dwdy)+ww(inp)*dwdz )

    ! magStrainSq = magStrain(inp)*magStrain(inp)
    ! gen(inp) = 2*abs(vis(inp)-viscos)*magStrainSq

  enddo

  !
  !=====================================
  ! VOLUME SOURCE TERMS 
  !=====================================
  do inp=1,numCells

    genp=max(gen(inp),zero)
    genn=min(gen(inp),zero)

    ! Add production term to the rhs:
    su(inp)=genp*vol(inp)  

    ! Add destruction term to the lhs:
    delta = vol(inp)**third
    sp(inp)=den(inp) * (Ceps*te(inp)**three_halfs/delta)* vol(inp)/(te(inp)+small)
    sp(inp)=sp(inp)-genn*vol(inp)/(te(inp)+small)


    !
    !=====================================
    ! VOLUME SOURCE TERMS: buoyancy
    !=====================================
    if(lcal(ien).and.lbuoy) then
      
      ! When bouy activated we need the freshest utt,vtt,wtt - turbulent heat fluxes
      call calcheatflux 

      if(boussinesq) then
         uttbuoy=-gravx*den(inp)*utt(inp)*vol(inp)*beta
         vttbuoy=-gravy*den(inp)*vtt(inp)*vol(inp)*beta
         wttbuoy=-gravz*den(inp)*wtt(inp)*vol(inp)*beta
      else
         uttbuoy=-gravx*den(inp)*utt(inp)*vol(inp)/(t(inp)+273.15)
         vttbuoy=-gravy*den(inp)*vtt(inp)*vol(inp)/(t(inp)+273.15)
         wttbuoy=-gravz*den(inp)*wtt(inp)*vol(inp)/(t(inp)+273.15)
      end if

      utp=max(uttbuoy,zero)
      vtp=max(vttbuoy,zero)
      wtp=max(wttbuoy,zero)
      utn=min(uttbuoy,zero)
      vtn=min(vttbuoy,zero)
      wtn=min(wttbuoy,zero)

      su(inp)=su(inp)+utp+vtp+wtp
      sp(inp)=sp(inp)-(utn+vtn+wtn)/(te(inp)+small)

    end if

    !
    !=====================================
    ! UNSTEADY TERM
    !=====================================
    if (ltransient) then
      if( bdf .or. cn ) then
        apotime = den(inp)*vol(inp)/timestep
        su(inp) = su(inp) + apotime*teo(inp)
        sp(inp) = sp(inp) + apotime
      elseif( bdf2 ) then
        apotime=den(inp)*vol(inp)/timestep
        su(inp) = su(inp) + apotime*( 2*teo(inp) - 0.5_dp*teoo(inp) )
        sp(inp) = sp(inp) + 1.5_dp*apotime
      endif
    endif


  ! End of TKE volume source terms
  enddo



!
! CALCULATE TERMS INTEGRATED OVER FACES
!

  ! Inner faces:                                             
  do i=1,numInnerFaces                                                       
    ijp = owner(i)
    ijn = neighbour(i)

    call facefluxsc( ijp, ijn, &
                     xf(i), yf(i), zf(i), arx(i), ary(i), arz(i), &
                     flmass(i), facint(i), gam, &
                     fi, dFidxi, prtr, cap, can, suadd )

    ! > Off-diagonal elements:

    ! (icell,jcell) matrix element:
    k = icell_jcell_csr_index(i)
    a(k) = can

    ! (jcell,icell) matrix element:
    k = jcell_icell_csr_index(i)
    a(k) = cap

    ! > Elements on main diagonal:

    ! ! (icell,icell) main diagonal element
    k = diag(ijp)
    a(k) = a(k) - can

    ! ! (jcell,jcell) main diagonal element
    k = diag(ijn)
    a(k) = a(k) - cap

    ! > Sources:

    su(ijp) = su(ijp) + suadd
    su(ijn) = su(ijn) - suadd 

  enddo



  !
  ! Boundary conditions
  !

  iWall = 0
  iPro = 0

  do ib=1,numBoundaries

    if ( bctype(ib) == 'process') then
    ! Faces on processor boundaries

      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijp = owner(iface)
        ijn = iBndValueStart(ib) + i

        iPro = iPro + 1

        call facefluxsc( ijp, ijn, &
                         xf(iface), yf(iface), zf(iface), arx(iface), ary(iface), arz(iface), &
                         flmass(iface), fpro(ipro), gam, &
                         fi, dfidxi, prtr, cap, can, suadd )

        ! > Off-diagonal elements:    
        apr(ipro) = can

        ! > Elements on main diagonal:
        sp(ijp) = sp(ijp) - can

        ! > Sources:
        su(ijp) = su(ijp) + suadd

      
      enddo

    elseif ( bctype(ib) == 'inlet' ) then

      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijp = owner(iface)
        ijb = iBndValueStart(ib) + i

        call facefluxsc( ijp, ijb, &
                         xf(iface), yf(iface), zf(iface), arx(iface), ary(iface), arz(iface), &
                         flmass(iface), &
                         Fi, dFidxi, prtr, cap, can, suadd)

        Sp(ijp) = Sp(ijp)-can

        Su(ijp) = Su(ijp)-can*Fi(ijb) + suadd

      end do

    elseif ( bctype(ib) == 'outlet' ) then

      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijp = owner(iface)
        ijb = iBndValueStart(ib) + i

        call facefluxsc( ijp, ijb, &
                         xf(iface), yf(iface), zf(iface), arx(iface), ary(iface), arz(iface), &
                         flmass(iface), &
                         FI, dFidxi, prtr, cap, can, suadd )

        Sp(ijp) = Sp(ijp)-can

        Su(ijp) = Su(ijp)-can*Fi(ijb) + suadd

      end do

    elseif ( bctype(ib) == 'wall') then

      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijp = owner(iface)
        ijb = iBndValueStart(ib) + i
        iWall = iWall + 1


        !
        ! > Wall boundary conditions for turbulence kinetic energy eq.
        !

        ! viss=viscos
        ! if(ypl(iWall).gt.ctrans) viss=visw(iWall)
        viss = max(viscos,visw(iWall))

        ! Face area 
        are = sqrt(arx(iface)**2+ary(iface)**2+arz(iface)**2)

        ! Face normals
        nxf = arx(iface)/are
        nyf = ary(iface)/are
        nzf = arz(iface)/are

        ! Magnitude of a cell center velocity projected on boundary face normal
        Vnp = U(ijp)*nxf+V(ijp)*nyf+W(ijp)*nzf

        ! Tangential velocity components 
        xtp = U(ijp)-Vnp*nxf
        ytp = V(ijp)-Vnp*nyf
        ztp = W(ijp)-Vnp*nzf

        ! Its magnitude
        Vtp = sqrt(xtp*xtp+ytp*ytp+ztp*ztp)

        ! Tangent direction - unit vector
        xtp = xtp/vtp
        ytp = ytp/vtp
        ztp = ztp/vtp

        ! projektovanje razlike brzina na pravac tangencijalne brzine u cell centru ijp
        Ut2 = abs( (U(ijb)-U(ijp))*xtp + (V(ijb)-V(ijp))*ytp + (W(ijb)-W(ijp))*ztp )

        Tau(iWall) = viss*Ut2/dnw(iWall)

        ! Production of TKE in wall adjecent cell
        ! First substract the standard production from source term
        su(ijp)=su(ijp)-gen(ijp)*vol(ijp)
        ! Calculate production for wall adjecent cell
        gen(ijp)=abs(tau(iWall))*cmu25*sqrt(te(ijp))/(dnw(iWall)*cappa)
        ! Add this production to source vector
        su(ijp)=su(ijp)+gen(ijp)*vol(ijp)


      enddo

    endif
    
  enddo ! Boundary conditions loop 


  ! Modify coefficients for Crank-Nicolson
  if (cn) then

      a = 0.5_dp*a ! Doesn't affect the main diagonal because it's still zero.

        do i = 1,numInnerFaces
            ijp = owner(i)
            ijn = neighbour(i)

            k = icell_jcell_csr_index(i)
            su(ijp) = su(ijp) - a(k)*teo(ijn)

            k = jcell_icell_csr_index(i)
            su(ijn) = su(ijn) - a(k)*teo(ijp)
        enddo

        ! Processor boundary
        
        iPro = 0

        do ib=1,numBoundaries

          if ( bctype(ib) == 'process') then
          ! Faces on processor boundaries

            do i=1,nfaces(ib)

              iface = startFace(ib) + i
              ijp = owner(iface)
              ijn = iBndValueStart(ib) + i

              iPro = iPro + 1

              ! This is relevant to previous loop over faces
              su(ijp) = su(ijp) - apr(ipro)*teo(ijn)

              ! This is relevant to next loop over cells
              su(ijp) = su(ijp) + apr(ipro)*teo(ijp)

            enddo

          endif
          
        enddo 

        do ijp=1,numCells
            apotime=den(ijp)*vol(ijp)/timestep
            off_diagonal_terms = sum( a( ioffset(ijp) : ioffset(ijp+1)-1 ) ) - a(diag(ijp))
            su(ijp) = su(ijp) + (apotime + off_diagonal_terms)*teo(ijp)
            sp(ijp) = sp(ijp)+apotime
        enddo
        
  endif

  ! Underrelaxation factors
  urfrs=urfr(ifi)
  urfms=urfm(ifi)

  ! Main diagonal term assembly and underrelaxation:
  do inp = 1,numCells

        ! NOTE for parallel:
        ! Contributions to main diagonal term from neighbour cells that are in other process domain
        ! are aleady in sp at this stage.
        a(diag(inp)) = sp(inp) 
        
        do k = ioffset(inp),ioffset(inp+1)-1
          if (k.eq.diag(inp)) cycle
          a(diag(inp)) = a(diag(inp)) -  a(k)
        enddo

        ! Underelaxation:
        a(diag(inp)) = a(diag(inp))*urfrs
        su(inp) = su(inp) + urfms*a(diag(inp))*fi(inp)
                    
  enddo

  ! Solve linear system:
  ! call jacobi(fi,ifi)
  call bicgstab(fi,ifi)

  !
  ! Update symmetry and outlet boundaries
  !
  do ib=1,numBoundaries

    if ( bctype(ib) == 'outlet' .or. bctype(ib) == 'symmetry' ) then

      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijp = owner(iface)
        ijb = iBndValueStart(ib) + i

        fi(ijb)=fi(ijp)

      enddo

    endif

  enddo

! Report range of scalar values and clip if negative
  fimin = minval(fi)
  fimax = maxval(fi)
  
! These field values cannot be negative
  if(fimin.lt.0.0_dp) fi = max(fi,small)

  call global_min(fimin)
  call global_max(fimax)

  if( myid .eq. 0 ) write(6,'(2x,es11.4,3a,es11.4)') fimin,' <= ',chvar(ifi),' <= ',fimax

  ! MPI exchange
  call exchange(fi)
  
end subroutine calcsc


subroutine modify_mu_eff()
!
! Update turbulent and effective viscosity.
!
  use types
  use parameters
  use geometry
  use variables
  implicit none

  integer :: i,inp
  integer :: iface,ijp,ijb,ib,iwall
  real(dp) :: visold
  real(dp) :: nxf,nyf,nzf,are
  real(dp) :: Vnp,Vtp,xtp,ytp,ztp
  real(dp) :: Ut2,Utau,viscw
  real(dp) :: third,delta

  third = 1./3.0_dp

  do inp=1,numCells
    ! Store old value
    visold=vis(inp)
    delta = vol(inp)**third
    ! Update effective viscosity:
    ! \mu_{eff}=\mu+\mu_t; \mu_t = C_k * k^{0.5} * Delta
    vis(inp)=viscos + den(inp)*ck*sqrt(te(inp))*delta
    ! Underelaxation
    vis(inp)=urf(ivis)*vis(inp)+(1.0_dp-urf(ivis))*visold
  enddo

  !
  ! Boundary faces 
  !

  iWall = 0

  do ib=1,numBoundaries

    if ( bctype(ib) == 'inlet' ) then

      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijp = owner(iface)
        ijb = iBndValueStart(ib) + i

        Vis(ijb) = Vis(ijp)

      end do

    elseif ( bctype(ib) == 'outlet' ) then

      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijp = owner(iface)
        ijb = iBndValueStart(ib) + i

        Vis(ijb) = Vis(ijp)

      enddo

    elseif ( bctype(ib) == 'symmetry') then

      ! Symmetry
      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijp = owner(iface)
        ijb = iBndValueStart(ib) + i

        Vis(ijb) = Vis(ijp)

      end do

    elseif ( bctype(ib) == 'wall') then

      do i=1,nfaces(ib)

        iface = startFace(ib) + i
        ijp = owner(iface)
        ijb = iBndValueStart(ib) + i
        iWall = iWall + 1

        !
        ! Wall boundaries - update Visw and Ypl
        !

        ! Face area 
        are = sqrt(arx(iface)**2+ary(iface)**2+arz(iface)**2)

        ! Face normals
        nxf = arx(iface)/are
        nyf = ary(iface)/are
        nzf = arz(iface)/are

        ! Magnitude of a cell center velocity projected on boundary face normal
        Vnp = U(ijp)*nxf+V(ijp)*nyf+W(ijp)*nzf

        ! Tangential velocity components 
        xtp = U(ijp)-Vnp*nxf
        ytp = V(ijp)-Vnp*nyf
        ztp = W(ijp)-Vnp*nzf

        ! Its magnitude
        Vtp = sqrt(xtp*xtp+ytp*ytp+ztp*ztp)

        ! Tangent direction
        xtp = xtp/vtp
        ytp = ytp/vtp
        ztp = ztp/vtp

        ! projektovanje razlike brzina na pravac tangencijalne brzine u cell centru ijp
        Ut2 = abs( (U(ijb)-U(ijp))*xtp + (V(ijb)-V(ijp))*ytp + (W(ijb)-W(ijp))*ztp )

        Tau(iWall) = viscos*Ut2/dnw(iWall)
        Utau = sqrt( Tau(iWall) / den(ijb) )
        ! ypl(iWall) = den(ijb)*Utau*dnw(iWall)/viscos

        ! ! Ima i ova varijanta
        ypl(iWall) = den(ijp)*cmu25*sqrt(te(ijp))*dnw(iWall)/viscos

        viscw = zero

        if(ypl(iWall) > ctrans) then
          viscw = ypl(iWall)*viscos*cappa/log(Elog*ypl(iWall))
        endif

        visw(iWall) = max(viscos,viscw)
        vis(ijb) = visw(iWall)

      enddo

    endif 

  enddo

  ! MPI exchange
  call exchange(vis)

end subroutine




end module k_eqn_eddy