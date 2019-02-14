! ----------------------------------------------------------------
! file: fluvial_link_module.f90
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Battelle Memorial Institute
! Pacific Northwest Laboratory
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Created July  3, 2017 by William A. Perkins
! Last Change: 2018-08-21 12:29:08 d3g096
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! MODULE fluvial_link_module
! ----------------------------------------------------------------
MODULE fluvial_link_module

  USE bc_module
  USE point_module
  USE link_module
  USE linear_link_module
  USE utility
  USE flow_coeff

  IMPLICIT NONE

  PRIVATE

  TYPE, PUBLIC, EXTENDS(linear_link_t) :: fluvial_link
     DOUBLE PRECISION :: latq, latqold
     DOUBLE PRECISION :: lpiexp
   CONTAINS
     PROCEDURE :: construct => fluvial_link_construct
     PROCEDURE :: initialize => fluvial_link_initialize
     PROCEDURE :: coeff => fluvial_link_coeff
     PROCEDURE :: hydro_update => fluvial_link_hupdate
  END type fluvial_link

  TYPE, PUBLIC, EXTENDS(fluvial_link) :: fluvial_hydro_link
     CONTAINS
       PROCEDURE :: initialize => fluvial_hydro_link_initialize
  END type fluvial_hydro_link

  DOUBLE PRECISION, PARAMETER :: alpha = 1.0
  DOUBLE PRECISION, PARAMETER :: theta = 1.0

CONTAINS

  ! ----------------------------------------------------------------
  ! SUBROUTINE fluvial_link_construct
  ! ----------------------------------------------------------------
  SUBROUTINE fluvial_link_construct(this)

    IMPLICIT NONE
    CLASS (fluvial_link), INTENT(INOUT) :: this

    CALL this%linear_link_t%construct()
    NULLIFY(this%latbc)
    this%latq = 0.0
    this%latqold = 0.0
    this%lpiexp = 0.0

  END SUBROUTINE fluvial_link_construct


  ! ----------------------------------------------------------------
  !  FUNCTION fluvial_link_initialize
  ! ----------------------------------------------------------------
  FUNCTION fluvial_link_initialize(this, ldata, bcman) RESULT(ierr)

    IMPLICIT NONE
    INTEGER :: ierr
    CLASS (fluvial_link), INTENT(INOUT) :: this
    CLASS (link_input_data), INTENT(IN) :: ldata
    CLASS (bc_manager_t), INTENT(IN) :: bcman
    CHARACTER (LEN=1024) :: msg

    ierr = this%linear_link_t%initialize(ldata, bcman)

    this%lpiexp = ldata%lpiexp
    IF (ldata%lbcid .GT. 0) THEN
       this%latbc => bcman%find(LATFLOW_BC_TYPE, ldata%lbcid)
       IF (.NOT. ASSOCIATED(this%latbc)) THEN
          WRITE (msg, *) 'link ', ldata%linkid, ': unknown lateral inflow id: ', &
               &ldata%lbcid
          CALL error_message(msg)
          ierr = ierr + 1
       END IF
    END IF

  END FUNCTION fluvial_link_initialize


  ! ----------------------------------------------------------------
  ! SUBROUTINE fluvial_link_coeff
  ! ----------------------------------------------------------------
  SUBROUTINE fluvial_link_coeff(this, dt, pt1, pt2, cf)
    USE fluvial_coeffs
    USE general_vars
    IMPLICIT NONE
    CLASS (fluvial_link), INTENT(INOUT) :: this
    DOUBLE PRECISION, INTENT(IN) :: dt
    TYPE (point_t), INTENT(IN) :: pt1, pt2
    TYPE (coeff), INTENT(OUT) :: cf

    TYPE (fluvial_state) :: s1, s2

    DOUBLE PRECISION :: y1, y2, d1, d2, q1, q2, a1, a2, b1, b2, k1, k2, ky1, ky2
    DOUBLE PRECISION :: fr1, fr2
    DOUBLE PRECISION :: dx

    ! FIXME: These need to come from the configuration:
    DOUBLE PRECISION :: gr

    gr = 32.2

    CALL pt1%assign(y1, d1, q1, a1, b1, k1, ky1, fr1)
    CALL pt2%assign(y2, d2, q2, a2, b2, k2, ky2, fr2)

    dx = ABS(pt1%x - pt2%x)
    s1%y = y1
    s1%d = d1
    s1%q = q1
    s1%a = a1
    s1%b = b1
    s1%k = k1
    s1%ky  = ky1
    s1%fr = fr1
    s2%y = y2
    s2%d = d2
    s2%q = q2
    s2%a = a2
    s2%b = b2
    s2%k = k2
    s2%ky  = ky2
    s2%fr = fr2
    
    CALL fluvial_coeff(s1, s2, cf, dx, dt, gr, &
         &this%latqold, this%latq, this%lpiexp, depth_threshold)

  END SUBROUTINE fluvial_link_coeff

  ! ----------------------------------------------------------------
  ! SUBROUTINE fluvial_link_hupdate
  ! ----------------------------------------------------------------
  SUBROUTINE fluvial_link_hupdate(this, grav, dt)
    IMPLICIT NONE
    CLASS (fluvial_link), INTENT(INOUT) :: this
    DOUBLE PRECISION, INTENT(IN) :: grav, dt

    CALL this%linear_link_t%hydro_update(grav, dt)

    IF (ASSOCIATED(this%latbc)) THEN
       this%latqold = this%latq
       this%latq = this%latbc%current_value
    END IF

  END SUBROUTINE fluvial_link_hupdate


  ! ----------------------------------------------------------------
  !  FUNCTION fluvial_hydro_link_initialize
  ! ----------------------------------------------------------------
  FUNCTION fluvial_hydro_link_initialize(this, ldata, bcman) RESULT(ierr)

    IMPLICIT NONE
    INTEGER :: ierr
    CLASS (fluvial_hydro_link), INTENT(INOUT) :: this
    CLASS (link_input_data), INTENT(IN) :: ldata
    CLASS (bc_manager_t), INTENT(IN) :: bcman
    CHARACTER (LEN=1024) :: msg

    ierr = 0

    IF (ldata%bcid .GT. 0) THEN
       this%usbc => bcman%find(HYDRO_BC_TYPE, ldata%bcid)
       IF (.NOT. ASSOCIATED(this%usbc) ) THEN
          WRITE (msg, *) 'link ', ldata%linkid, ': unknown hydro BC id: ', ldata%bcid
          CALL error_message(msg)
          ierr = ierr + 1
       END IF
    ELSE 
       WRITE (msg, *) 'hydro link ', ldata%linkid, ' requires a hydro BC, none specified'
       CALL error_message(msg)
       ierr = ierr + 1
    END IF

    ierr = ierr + this%fluvial_link%initialize(ldata, bcman)
  END FUNCTION fluvial_hydro_link_initialize

  

END MODULE fluvial_link_module