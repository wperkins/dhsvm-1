! ----------------------------------------------------------------
! file: linear_link_module.f90
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Battelle Memorial Institute
! Pacific Northwest Laboratory
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Created June 28, 2017 by William A. Perkins
! Last Change: 2019-02-13 12:05:30 d3g096
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! MODULE linear_link_module
! ----------------------------------------------------------------
MODULE linear_link_module
  USE link_module
  USE point_module
  USE bc_module
  USE cross_section
  USE section_handler_module
  USE mass1_config
  USE general_vars, ONLY: depth_threshold, depth_minimum
  USE flow_coeff

  IMPLICIT NONE

  PRIVATE

  TYPE, PUBLIC, EXTENDS(link_t) :: linear_link_t
     INTEGER :: npoints
     INTEGER :: input_option
     TYPE (point_t), DIMENSION(:),POINTER :: pt
   CONTAINS
     PROCEDURE :: initialize => linear_link_initialize
     PROCEDURE :: readpts => linear_link_readpts
     PROCEDURE :: points => linear_link_points
     PROCEDURE :: length => linear_link_length
     PROCEDURE :: q_up => linear_link_q_up
     PROCEDURE :: q_down => linear_link_q_down
     PROCEDURE :: y_up => linear_link_y_up
     PROCEDURE :: y_down => linear_link_y_down
     PROCEDURE :: c_up => linear_link_c_up
     PROCEDURE :: c_down => linear_link_c_down
     PROCEDURE :: set_initial => linear_link_set_initial
     PROCEDURE :: read_restart => linear_link_read_restart
     PROCEDURE :: write_restart => linear_link_write_restart
     PROCEDURE :: coeff => linear_link_coeff
     PROCEDURE :: forward_sweep => linear_link_forward
     PROCEDURE :: backward_sweep => linear_link_backward
     PROCEDURE :: hydro_update => linear_link_hupdate
     PROCEDURE :: max_courant => linear_link_max_courant
     PROCEDURE :: max_diffuse => linear_link_max_diffuse
     PROCEDURE :: point => linear_link_point
     PROCEDURE :: check => linear_link_check
     PROCEDURE :: destroy => linear_link_destroy
  END type linear_link_t

CONTAINS

  ! ----------------------------------------------------------------
  !  FUNCTION linear_link_initialize
  ! ----------------------------------------------------------------
  FUNCTION linear_link_initialize(this, ldata, bcman) RESULT(ierr)

    IMPLICIT NONE
    INTEGER :: ierr
    CLASS (linear_link_t), INTENT(INOUT) :: this
    CLASS (link_input_data), INTENT(IN) :: ldata
    CLASS (bc_manager_t), INTENT(IN) :: bcman
    CHARACTER (LEN=1024) :: msg

    ierr = 0
    this%id = ldata%linkid
    this%npoints = ldata%npt
    this%dsid = ldata%dsid
    this%input_option = ldata%inopt

    ALLOCATE(this%pt(this%npoints))

    ! find the "link" bc, if any; children can set this and it will be preserved

    IF (.NOT. ASSOCIATED(this%usbc)) THEN
       IF (ldata%bcid .NE. 0) THEN
          this%usbc => bcman%find(LINK_BC_TYPE, ldata%bcid)
          IF (.NOT. ASSOCIATED(this%usbc) ) THEN
             WRITE (msg, *) 'link ', ldata%linkid, ': unknown link BC id: ', ldata%bcid
             CALL error_message(msg)
             ierr = ierr + 1
          END IF
       END IF
    END IF

    ! find the downstream bc, if any; children can set this and it will be preserved

    IF (.NOT. ASSOCIATED(this%dsbc)) THEN
       IF (ldata%dsbcid .NE. 0) THEN
          this%dsbc => bcman%find(LINK_BC_TYPE, ldata%dsbcid)
          IF (.NOT. ASSOCIATED(this%dsbc) ) THEN
             WRITE (msg, *) 'link ', ldata%linkid, &
                  &': unknown downstream BC id: ', ldata%dsbcid
             CALL error_message(msg)
             ierr = ierr + 1
          END IF
       END IF
    END IF

  END FUNCTION linear_link_initialize

  ! ----------------------------------------------------------------
  !  FUNCTION linear_link_readpts
  ! ----------------------------------------------------------------
  FUNCTION linear_link_readpts(this, theconfig, sectman, punit, lineno) RESULT(ierr)
    IMPLICIT NONE
    INTEGER :: ierr
    CLASS (linear_link_t), INTENT(INOUT) :: this
    TYPE (configuration_t), INTENT(IN) :: theconfig
    CLASS (section_handler), INTENT(INOUT) :: sectman
    INTEGER, INTENT(IN) :: punit
    INTEGER, INTENT(INOUT) :: lineno
    INTEGER :: iostat
    CHARACTER (LEN=1024) :: msg
    INTEGER :: linkid, pnum, sectid, i
    DOUBLE PRECISION :: x, thalweg, manning, kdiff, ksurf
    DOUBLE PRECISION :: length, delta_x, slope, start_el, end_el
    CLASS (xsection_t), POINTER :: xsect
    DOUBLE PRECISION :: cl_factor

    ierr = 0
    cl_factor = theconfig%channel_len_factor()

    WRITE(msg, *) "Reading/building points for link = ", this%id, &
         &", input option = ", this%input_option, &
         &", points = ", this%npoints, &
         &", length factor = ", cl_factor
    CALL status_message(msg)

    SELECT CASE(this%input_option)
    CASE(1)                    ! point based input
       DO i=1,this%npoints
          READ(punit, *, IOSTAT=iostat)&
               &linkid, &
               &pnum, &
               &x, &
               &sectid, &
               &thalweg, &
               &manning, &
               &kdiff, &
               &ksurf

          IF (IS_IOSTAT_END(iostat)) THEN
             WRITE(msg, *) 'Premature end of file near line ', lineno, &
                  &' reading points for link ', this%id
             CALL error_message(msg)
             ierr = ierr + 1
             RETURN
          ELSE IF (iostat .NE. 0) THEN
             WRITE(msg, *) 'Read error near line ', lineno, &
                  &' reading points for link ', this%id
             CALL error_message(msg)
             ierr = ierr + 1
             RETURN
          END IF

          lineno = lineno + 1

          ! Convert lengths to internal length units
          x = x*cl_factor

          this%pt(i)%x = x
          this%pt(i)%thalweg = thalweg
          IF (manning .LE. 0.0) THEN
             WRITE(msg, *) 'link ', this%id, ', point ', pnum, &
                  &': error: invalid value for mannings coefficient: ', &
                  &manning
             CALL error_message(msg)
             ierr = ierr + 1
             CYCLE
          END IF
          this%pt(i)%manning = manning
          this%pt(i)%kstrick = theconfig%res_coeff/this%pt(i)%manning
          this%pt(i)%k_diff = kdiff

          ! ksurf is ignored

          xsect => sectman%find(sectid)
          IF (.NOT. ASSOCIATED(xsect)) THEN
             WRITE(msg, *) "link ", this%id, ", point = ", pnum, &
                  &": error: cannot find cross section ", sectid
             CALL error_message(msg)
          END IF
          this%pt(i)%xsection%p => xsect

       END DO

    CASE(2)                    ! link based input

       READ(punit, *, IOSTAT=iostat) &
            &linkid, &
            &length, &
            &start_el, &
            &end_el, &
            &sectid, &
            &manning, &
            &kdiff, &
            &ksurf

       ! Convert lengths to internal length units
       length = length*cl_factor

       IF (manning .LE. 0.0) THEN
          WRITE(msg, *) 'link ', this%id,  &
               &': error: invalid value for mannings coefficient: ', &
               &manning
          CALL error_message(msg)
          ierr = ierr + 1
       END IF

       delta_x = length/(this%npoints - 1)
       slope = (start_el - end_el)/length

       xsect =>  sectman%find(sectid)
       IF (.NOT. ASSOCIATED(xsect)) THEN
          WRITE(msg, *) "link ", this%id, "error: cannot find cross section ", sectid
          CALL error_message(msg)
          ierr = ierr + 1
       END IF

       DO i=1, this%npoints
          IF (i .EQ. 1)THEN
             this%pt(i)%x = 0.0
             this%pt(i)%thalweg = start_el
          ELSE
             this%pt(i)%x = this%pt(i-1)%x + delta_x
             this%pt(i)%thalweg = this%pt(i-1)%thalweg - slope*delta_x
          ENDIF

          this%pt(i)%manning = manning
          this%pt(i)%kstrick = theconfig%res_coeff/this%pt(i)%manning
          this%pt(i)%k_diff = kdiff
          this%pt(i)%xsection%p => xsect
          ! ksurf is ignored

       END DO

    CASE DEFAULT
       
       WRITE (msg, *) 'link ', this%id, &
            &': error: unknown input option: ', this%input_option
       CALL error_message(msg)
       ierr = ierr + 1
    END SELECT

  END FUNCTION linear_link_readpts

  ! ----------------------------------------------------------------
  !  FUNCTION linear_link_points
  ! ----------------------------------------------------------------
  FUNCTION linear_link_points(this) RESULT(n)

    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(IN) :: this
    INTEGER :: n
    n = this%npoints
  END FUNCTION linear_link_points

  ! ----------------------------------------------------------------
  !  FUNCTION linear_link_length
  ! ----------------------------------------------------------------
  FUNCTION linear_link_length(this) RESULT(len)

    IMPLICIT NONE
    DOUBLE PRECISION :: len
    CLASS (linear_link_t), INTENT(IN) :: this
    
    len = ABS(this%pt(1)%x - this%pt(this%npoints)%x)

  END FUNCTION linear_link_length


  ! ----------------------------------------------------------------
  ! DOUBLE PRECISION FUNCTION linear_link_q_up
  ! ----------------------------------------------------------------
  DOUBLE PRECISION FUNCTION linear_link_q_up(this)
    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(IN) :: this
    INTEGER :: n
    n = 1
    linear_link_q_up = this%pt(n)%hnow%q
  END FUNCTION linear_link_q_up


  ! ----------------------------------------------------------------
  ! DOUBLE PRECISION FUNCTION linear_link_q_down
  ! ----------------------------------------------------------------
  DOUBLE PRECISION FUNCTION linear_link_q_down(this)
    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(IN) :: this
    INTEGER :: n
    n = this%npoints
    linear_link_q_down = this%pt(n)%hnow%q
  END FUNCTION linear_link_q_down


  ! ----------------------------------------------------------------
  ! DOUBLE PRECISION FUNCTION linear_link_y_up
  ! ----------------------------------------------------------------
  DOUBLE PRECISION FUNCTION linear_link_y_up(this)
    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(IN) :: this
    INTEGER :: n
    n = 1
    linear_link_y_up = this%pt(n)%hnow%y
  END FUNCTION linear_link_y_up


  ! ----------------------------------------------------------------
  ! DOUBLE PRECISION FUNCTION linear_link_y_down
  ! ----------------------------------------------------------------
  DOUBLE PRECISION FUNCTION linear_link_y_down(this)
    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(IN) :: this
    INTEGER :: n
    n = this%npoints
    linear_link_y_down = this%pt(n)%hnow%y
  END FUNCTION linear_link_y_down


  ! ----------------------------------------------------------------
  ! DOUBLE PRECISION FUNCTION linear_link_c_up
  ! ----------------------------------------------------------------
  DOUBLE PRECISION FUNCTION linear_link_c_up(this, ispecies)
    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(IN) :: this
    INTEGER, INTENT(IN) :: ispecies
    linear_link_c_up = 0.0
  END FUNCTION linear_link_c_up


  ! ----------------------------------------------------------------
  ! DOUBLE PRECISION FUNCTION linear_link_c_down
  ! ----------------------------------------------------------------
  DOUBLE PRECISION FUNCTION linear_link_c_down(this, ispecies)
    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(IN) :: this
    INTEGER, INTENT(IN) :: ispecies
    linear_link_c_down = 0.0
  END FUNCTION linear_link_c_down

  ! ----------------------------------------------------------------
  ! SUBROUTINE linear_link_set_initial
  ! ----------------------------------------------------------------
  SUBROUTINE linear_link_set_initial(this, stage, discharge, c)
    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(INOUT) :: this
    DOUBLE PRECISION, INTENT(IN) :: stage, discharge, c(:)
    INTEGER :: i

    DO i = 1, this%npoints
       this%pt(i)%hnow%y = MAX(stage, this%pt(i)%thalweg + depth_minimum)
       this%pt(i)%hold%y = this%pt(i)%hnow%y
       this%pt(i)%hnow%q = discharge
       this%pt(i)%hold%q = this%pt(i)%hnow%q
    END DO

  END SUBROUTINE linear_link_set_initial


  ! ----------------------------------------------------------------
  ! SUBROUTINE linear_link_read_restart
  ! ----------------------------------------------------------------
  SUBROUTINE linear_link_read_restart(this, iunit)

    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(INOUT) :: this
    INTEGER, INTENT(IN) :: iunit
    INTEGER :: i, junk, iostat, ierr
    DOUBLE PRECISION :: c(2)
    CHARACTER (LEN=1024) :: msg

    ! FIXME: transport
    c = 0.0
    ierr = 0

    DO i = 1, this%npoints
       READ(iunit, IOSTAT=iostat) junk, junk, &
            &this%pt(i)%hnow%q, &
            &this%pt(i)%hnow%y, &
            &c(1), c(2)
       IF (IS_IOSTAT_END(iostat)) THEN
          WRITE(msg, *) 'link ', this%id, &
               &': premature end of file reading restart for point ', i
          CALL error_message(msg)
          ierr = ierr + 1
          EXIT
       ELSE IF (iostat .NE. 0) THEN
          WRITE(msg, *) 'link ', this%id, &
               &': error reading restart for point ', i
          CALL error_message(msg)
          ierr = ierr + 1
          EXIT
       END IF
    END DO

    IF (ierr .GT. 0) THEN
       WRITE(msg, *) 'problem reading restart for link', this%id
       CALL error_message(msg, fatal=.TRUE.)
    END IF

  END SUBROUTINE linear_link_read_restart

  ! ----------------------------------------------------------------
  ! SUBROUTINE linear_link_write_restart
  ! ----------------------------------------------------------------
  SUBROUTINE linear_link_write_restart(this, iunit)

    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(IN) :: this
    INTEGER, INTENT(IN) :: iunit
    INTEGER :: i
    DOUBLE PRECISION :: c

    ! FIXME: transport
    c = 0.0

    DO i = 1, this%npoints
       WRITE(iunit) this%id, i, &
            &this%pt(i)%hnow%q, &
            &this%pt(i)%hnow%y, &
            &c, c
    END DO
  END SUBROUTINE linear_link_write_restart



  ! ----------------------------------------------------------------
  ! SUBROUTINE linear_link_coeff
  ! ----------------------------------------------------------------
  SUBROUTINE linear_link_coeff(this, dt, pt1, pt2, cf)

    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(INOUT) :: this
    DOUBLE PRECISION, INTENT(IN) :: dt
    TYPE (point_t), INTENT(IN) :: pt1, pt2
    TYPE (coeff), INTENT(OUT) :: cf

    CALL error_message("This should not happen: linear_link_coeff should be overridden", &
         &fatal=.TRUE.)
  END SUBROUTINE linear_link_coeff


  ! ----------------------------------------------------------------
  ! SUBROUTINE linear_link_forward
  ! ----------------------------------------------------------------
  SUBROUTINE linear_link_forward(this, deltat)

    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(INOUT) :: this
    DOUBLE PRECISION, INTENT(IN) :: deltat

    INTEGER :: point
    DOUBLE PRECISION :: bcval, denom
    TYPE (coeff) :: cf

    point = 1
    IF (ASSOCIATED(this%ucon)) THEN
       this%pt(point)%sweep%e = this%ucon%coeff_e()
       this%pt(point)%sweep%f = this%ucon%coeff_f()
    ELSE
       IF (ASSOCIATED(this%usbc)) THEN
          bcval = this%usbc%current_value
       ELSE 
          bcval = 0.0
       END IF
       this%pt(point)%hnow%q = bcval
       this%pt(point)%sweep%e = 0.0
       this%pt(point)%sweep%f = bcval - this%pt(point)%hnow%q
    END IF

    DO point = 1, this%npoints - 1
       CALL this%coeff(deltat, this%pt(point), this%pt(point + 1), cf)
       denom = (cf%c*cf%dp - cf%cp*cf%d)
       this%pt(point)%sweep%l = (cf%a*cf%dp - cf%ap*cf%d)/denom
       this%pt(point)%sweep%m = (cf%b*cf%dp - cf%bp*cf%d)/denom
       this%pt(point)%sweep%n = (cf%d*cf%gp - cf%dp*cf%g)/denom

       denom = cf%b - this%pt(point)%sweep%m*(cf%c + cf%d*this%pt(point)%sweep%e)
       this%pt(point+1)%sweep%e = &
            &(this%pt(point)%sweep%l*(cf%c + cf%d*this%pt(point)%sweep%e) - cf%a)/denom
       this%pt(point+1)%sweep%f = &
            &(this%pt(point)%sweep%n*(cf%c + cf%d*this%pt(point)%sweep%e) + &
            &cf%d*this%pt(point)%sweep%f + cf%g)/denom

    END DO


  END SUBROUTINE linear_link_forward


  ! ----------------------------------------------------------------
  ! SUBROUTINE linear_link_backward
  ! ----------------------------------------------------------------
  SUBROUTINE linear_link_backward(this, dsbc_type)

    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(INOUT) :: this
    INTEGER, INTENT(IN) :: dsbc_type
    DOUBLE PRECISION :: bcval, dy, dq
    INTEGER :: point
    

    point = this%npoints
    
    IF (ASSOCIATED(this%dcon)) THEN

       dy = this%dcon%elev() - this%pt(point)%hnow%y
       dq = this%pt(point)%sweep%e*dy + this%pt(point)%sweep%f

    ELSE IF (ASSOCIATED(this%dsbc)) THEN

       bcval = this%dsbc%current_value
       SELECT CASE(dsbc_type)
       CASE(1)
          ! given downstream stage
          dy = bcval - this%pt(point)%hnow%y
          dq = this%pt(point)%sweep%e*dy + this%pt(point)%sweep%f
       CASE(2)
          ! given downstream discharge
          dq = bcval - this%pt(point)%hnow%q
          dy = (dq - this%pt(point)%sweep%f)/this%pt(point)%sweep%e
       END SELECT
    ELSE 
       CALL error_message("This should not happen in linear_link_backward", &
            &fatal=.TRUE.)
    END IF

    this%pt(point)%hnow%y = this%pt(point)%hnow%y + dy
    this%pt(point)%hnow%q = this%pt(point)%hnow%q + dq

    DO point = this%npoints - 1, 1, -1
       dy = this%pt(point)%sweep%l*dy + this%pt(point)%sweep%m*dq + this%pt(point)%sweep%n
       dq = this%pt(point)%sweep%e*dy + this%pt(point)%sweep%f

       this%pt(point)%hnow%y = this%pt(point)%hnow%y + dy
       this%pt(point)%hnow%q = this%pt(point)%hnow%q + dq
       
    END DO

    

  END SUBROUTINE linear_link_backward


  ! ----------------------------------------------------------------
  ! SUBROUTINE linear_link_hupdate
  ! ----------------------------------------------------------------
  SUBROUTINE linear_link_hupdate(this, grav, dt)

    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(INOUT) :: this
    DOUBLE PRECISION, INTENT(IN) :: grav, dt

    INTEGER :: p
    DOUBLE PRECISION :: dx

    DO p = 1, this%npoints
       IF (p .GE. this%npoints) THEN
          dx = ABS(this%pt(p-1)%x - this%pt(p)%x)
       ELSE 
          dx = ABS(this%pt(p+1)%x - this%pt(p)%x)
       END IF
       CALL this%pt(p)%hydro_update(grav, dt, dx)
    END DO

  END SUBROUTINE linear_link_hupdate

  ! ----------------------------------------------------------------
  ! DOUBLE PRECISION FUNCTION linear_link_max_courant
  ! ----------------------------------------------------------------
  FUNCTION linear_link_max_courant(this, dt) RESULT(cnmax)

    IMPLICIT NONE
    DOUBLE PRECISION :: cnmax
    CLASS (linear_link_t), INTENT(IN) :: this
    DOUBLE PRECISION, INTENT(IN) :: dt

    INTEGER :: i

    cnmax = 0.0
    DO i = 1, this%npoints
       cnmax = MAX(cnmax, this%pt(i)%hnow%courant_num)
    END DO

  END FUNCTION linear_link_max_courant

  ! ----------------------------------------------------------------
  ! DOUBLE PRECISION FUNCTION linear_link_max_diffuse
  ! ----------------------------------------------------------------
  FUNCTION linear_link_max_diffuse(this, dt) RESULT(dmax)

    IMPLICIT NONE
    DOUBLE PRECISION :: dmax
    CLASS (linear_link_t), INTENT(IN) :: this
    DOUBLE PRECISION, INTENT(IN) :: dt

    INTEGER :: i

    dmax = 0.0
    DO i = 1, this%npoints
       dmax = MAX(dmax, this%pt(i)%hnow%diffuse_num)
    END DO

  END FUNCTION linear_link_max_diffuse


  ! ----------------------------------------------------------------
  !  FUNCTION linear_link_point
  ! ----------------------------------------------------------------
  FUNCTION linear_link_point(this, idx) RESULT(pt)
    IMPLICIT NONE
    TYPE (point_t), POINTER :: pt
    CLASS (linear_link_t), INTENT(IN) :: this
    INTEGER, INTENT(IN) :: idx
    CHARACTER (LEN=1024) :: msg
    
    NULLIFY(pt)
    IF (idx .GE. 0 .AND. idx .LE. this%npoints) THEN
       pt => this%pt(idx)
    ELSE 
       WRITE(msg, *) 'Invalid point index (', idx, ') for link ', &
            &this%id, ', npoint = ', this%npoints
       CALL error_message(msg, FATAL=.FALSE.)
    END IF
  END FUNCTION linear_link_point

  ! ----------------------------------------------------------------
  !  FUNCTION linear_link_check
  ! ----------------------------------------------------------------
  FUNCTION linear_link_check(this) RESULT(ierr)

    IMPLICIT NONE
    INTEGER :: ierr
    CLASS (linear_link_t), INTENT(INOUT) :: this
    INTEGER :: i
    CHARACTER (LEN=1024) :: msg
    CLASS (point_t), POINTER :: pt

    ! why cant I do this
    ! ierr = this%link_t%check()
    ierr = 0
    IF (this%points() .LE. 0) THEN
       WRITE(msg, *) 'link ', this%id, ': has zero points?'
       CALL error_message(msg)
       ierr = ierr + 1
    ELSE
       DO i = 1, this%points()
          pt => this%point(i)
          IF (.NOT. ASSOCIATED(pt%xsection%p)) THEN
             WRITE (msg, *) 'link ', this%id, ': point ', i, &
                  &': no cross section assigned'
             CALL error_message(msg)
             ierr = ierr + 1
          END IF
       END DO
            
    END IF
  END FUNCTION linear_link_check

  ! ----------------------------------------------------------------
  ! SUBROUTINE linear_link_destroy
  ! ----------------------------------------------------------------
  SUBROUTINE linear_link_destroy(this)
    IMPLICIT NONE
    CLASS (linear_link_t), INTENT(INOUT) :: this

    DEALLOCATE(this%pt)

  END SUBROUTINE linear_link_destroy

  


END MODULE linear_link_module