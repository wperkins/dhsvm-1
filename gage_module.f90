! ----------------------------------------------------------------
! file: gage_module.f90
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Battelle Memorial Institute
! Pacific Northwest Laboratory
! ----------------------------------------------------------------
! ----------------------------------------------------------------
! Created January  8, 2018 by William A. Perkins
! Last Change: 2018-02-02 11:08:11 d3g096
! ----------------------------------------------------------------

! ----------------------------------------------------------------
! MODULE gage_module
! ----------------------------------------------------------------
MODULE gage_module

  USE utility
  USE date_time
  USE dlist_module
  USE point_module
  USE link_manager_module
  
  IMPLICIT NONE

  PRIVATE

  ! ----------------------------------------------------------------
  ! TYPE gage_t
  ! ----------------------------------------------------------------
  TYPE, PRIVATE :: gage_t
     INTEGER :: link_id, point_idx
     CHARACTER (LEN=256) :: gagename
     CLASS (point_t), POINTER :: pt
     CHARACTER (LEN=1024), PRIVATE :: filename
     LOGICAL, PRIVATE :: firstwrite = .TRUE.
   CONTAINS
     PROCEDURE, PRIVATE :: name => gage_name
     ! PROCEDURE, PRIVATE :: header 
     ! PROCEDURE, PRIVATE 
     PROCEDURE :: output => gage_output
     PROCEDURE :: destroy => gage_destroy
  END type gage_t

  ! ----------------------------------------------------------------
  ! TYPE gage_ptr
  ! ----------------------------------------------------------------
  TYPE, PRIVATE :: gage_ptr
     CLASS (gage_t), POINTER :: p
  END type gage_ptr

  ! ----------------------------------------------------------------
  ! TYPE gage_list
  ! ----------------------------------------------------------------
  TYPE, PRIVATE, EXTENDS(dlist) :: gage_list
   CONTAINS 
     PROCEDURE :: push => gage_list_push
     PROCEDURE :: pop => gage_list_pop
     PROCEDURE :: clear => gage_list_clear
     PROCEDURE :: current => gage_list_current
  END type gage_list

  ! ----------------------------------------------------------------
  ! TYPE gage_manager
  ! ----------------------------------------------------------------
  TYPE, PUBLIC :: gage_manager
     TYPE (gage_list) :: gages
   CONTAINS
     PROCEDURE :: read => gage_manager_read
     PROCEDURE :: output => gage_manager_output
     PROCEDURE :: destroy => gage_manager_destroy
  END type gage_manager
  
CONTAINS

  ! ----------------------------------------------------------------
  !  FUNCTION gage_name
  ! ----------------------------------------------------------------
  FUNCTION gage_name(this) RESULT (oname)

    IMPLICIT NONE
    CLASS (gage_t), INTENT(INOUT) :: this
    CHARACTER (LEN=1024) :: oname
    CHARACTER (LEN=80) :: string1, string2

    IF (LEN(TRIM(this%filename)) .LE. 0) THEN
       this%filename = ''
       IF (LEN(TRIM(this%gagename)) .GT. 0) THEN
          this%filename = 'ts' // this%gagename // '.out'
       ELSE 
          WRITE(string1, *) this%link_id
          string1 = ADJUSTL(string1)
          WRITE(string2, *) this%point_idx
          string2 = ADJUSTL(string2)
          this%filename = 'ts' // TRIM(string1) // TRIM(string2) // '.out'
       END IF
    END IF
    oname = this%filename
  END FUNCTION gage_name

  ! ----------------------------------------------------------------
  ! SUBROUTINE gage_output
  ! ----------------------------------------------------------------
  SUBROUTINE gage_output(this, date_string, time_string)
    IMPLICIT NONE
    CLASS (gage_t), INTENT(INOUT) :: this
    CHARACTER (LEN=*), INTENT(IN) :: date_string, time_string

    INTEGER, PARAMETER :: gunit = 51
    DOUBLE PRECISION :: depth

    IF (this%firstwrite) THEN
       CALL open_new(this%name(), gunit)
    ELSE 
       OPEN(gunit, FILE=this%name(), ACTION="WRITE", POSITION="APPEND")
    END IF
    this%firstwrite = .FALSE.
    
    ASSOCIATE( pt => this%pt, h => this%pt%hnow, pr => this%pt%xsprop )
      depth = h%y - pt%thalweg
      WRITE(gunit,1010) date_string, time_string, &
           &h%y, h%q, h%v , depth, &
           & 0.0 , 0.0, 0.0, 0.0, &
           &pt%thalweg, pr%area, pr%topwidth, pr%hydrad,&
           &h%froude_num, h%friction_slope, h%bed_shear
    END ASSOCIATE
    
1010 FORMAT(a10,2x,a8,2x,f8.2,2x,f12.2,2x,f6.2,2x,f7.2,2x,f10.2,2x,f6.2,2x,f6.2,2x,f6.1,2x, &
          f8.2,2x,es10.2,2x, &
          f8.2,2x,f6.2,f6.2,es10.2,2x,es10.2)
     CLOSE(gunit)
  END SUBROUTINE gage_output


  ! ----------------------------------------------------------------
  ! SUBROUTINE gage_destroy
  ! ----------------------------------------------------------------
  SUBROUTINE gage_destroy(this)

    IMPLICIT NONE
    CLASS (gage_t), INTENT(INOUT) :: this

    NULLIFY(this%pt)

  END SUBROUTINE gage_destroy


  ! ----------------------------------------------------------------
  ! SUBROUTINE gage_list_push
  ! ----------------------------------------------------------------
  SUBROUTINE gage_list_push(this, gage)
    IMPLICIT NONE
    CLASS (gage_list), INTENT(INOUT) :: this
    CLASS (gage_t), POINTER, INTENT(IN) :: gage
    TYPE (gage_ptr), POINTER :: ptr
    CLASS(*), POINTER :: p

    ALLOCATE(ptr)
    ptr%p => gage
    p => ptr
    CALL this%genpush(p)
  END SUBROUTINE gage_list_push

  ! ----------------------------------------------------------------
  !  FUNCTION gage_list_pop
  ! ----------------------------------------------------------------
  FUNCTION gage_list_pop(this) RESULT(gage)
    IMPLICIT NONE
    CLASS (gage_list), INTENT(INOUT) :: this
    CLASS (gage_t), POINTER :: gage
    TYPE (gage_ptr), POINTER :: ptr
    CLASS(*), POINTER :: p

    NULLIFY(gage)
    p => this%genpop()

    IF (ASSOCIATED(p)) THEN
       SELECT TYPE (p)
       TYPE IS (gage_ptr)
          ptr => p
          gage => ptr%p
          DEALLOCATE(ptr)
       END SELECT
    END IF
    RETURN
  END FUNCTION gage_list_pop

  ! ----------------------------------------------------------------
  ! SUBROUTINE gage_list_clear
  ! ----------------------------------------------------------------
  SUBROUTINE gage_list_clear(this)
    IMPLICIT NONE
    CLASS (gage_list), INTENT(INOUT) :: this
    CLASS (gage_t), POINTER :: gage

    DO WHILE (.TRUE.)
       gage => this%pop()
       IF (ASSOCIATED(gage)) THEN
          CALL gage%destroy()
          DEALLOCATE(gage)
       ELSE 
          EXIT
       END IF
    END DO
  END SUBROUTINE gage_list_clear

  ! ----------------------------------------------------------------
  !  FUNCTION gage_list_current
  ! ----------------------------------------------------------------
  FUNCTION gage_list_current(this) RESULT(gage)
    IMPLICIT NONE
    CLASS (gage_t), POINTER :: gage
    CLASS (gage_list) :: this
    TYPE (gage_ptr), POINTER :: ptr
    CLASS(*), POINTER :: p

    NULLIFY(gage)
    IF (ASSOCIATED(this%cursor)) THEN
       p => this%cursor%data
       IF (ASSOCIATED(p)) THEN
          SELECT TYPE (p)
          TYPE IS (gage_ptr)
             ptr => p
             gage => ptr%p
          END SELECT
       END IF
    END IF
  END FUNCTION gage_list_current

  ! ----------------------------------------------------------------
  ! SUBROUTINE gage_manager_read
  ! ----------------------------------------------------------------
  SUBROUTINE gage_manager_read(this, fname, linkman)

    IMPLICIT NONE
    CLASS (gage_manager), INTENT(INOUT) :: this
    CHARACTER (LEN=*), INTENT(IN) :: fname
    CLASS (link_manager_t), INTENT(IN) :: linkman

    INTEGER, PARAMETER :: gcunit = 33
    INTEGER :: line, ierr
    INTEGER :: linkid, pointidx
    CHARACTER (LEN=256) :: gname
    CLASS (gage_t), POINTER :: gage
    CLASS (link_t), POINTER :: link
    CLASS (point_t), POINTER :: point
    CHARACTER (LEN=1024) :: msg

    CALL open_existing(fname, gcunit, fatal=.TRUE.)

    line = 0
    ierr = 0
    DO WHILE(.TRUE.)
       line = line + 1
       gname = ""
       READ(gcunit,*, END=100, ERR=200) linkid, pointidx, gname
       link => linkman%find(linkid)
       IF (.NOT. ASSOCIATED(link)) THEN
          WRITE (msg, *) TRIM(fname), ", line ", line, ": unknown link id: ", linkid
          CALL error_message(msg)
          ierr = ierr + 1
          CYCLE
       END IF

       point => link%point(pointidx)
       IF (.NOT. ASSOCIATED(point)) THEN
          WRITE (msg, *) TRIM(fname), ", line ", line, ": unknown point index: ", pointidx
          CALL error_message(msg)
          ierr = ierr + 1
          CYCLE
       END IF
          
       ALLOCATE(gage)

       gage%filename = ""
       gage%gagename = ""
       gage%link_id = linkid
       gage%point_idx = pointidx
       IF (LEN(TRIM(gname)) .GT. 0) THEN
          gage%gagename = gname
       END IF
       gage%pt => point

       CALL this%gages%push(gage)
       
    END DO

200 CONTINUE
    WRITE (msg, *) TRIM(fname), ", line ", line, ": I/O error in gage control file"
    CALL error_message(msg, FATAL=.TRUE.)
100 CONTINUE
    CLOSE(gcunit)
    IF (ierr .GT. 0) THEN
       WRITE (msg, *) TRIM(fname), ": error(s) reading"
       CALL error_message(msg, FATAL=.TRUE.)
    END IF
    RETURN
  END SUBROUTINE gage_manager_read

  ! ----------------------------------------------------------------
  ! SUBROUTINE gage_manager_output
  ! ----------------------------------------------------------------
  SUBROUTINE gage_manager_output(this, time)

    IMPLICIT NONE
    CLASS (gage_manager), INTENT(INOUT) :: this
    DOUBLE PRECISION, INTENT(IN) :: time

    CHARACTER (LEN=20) :: date_string, time_string
    CLASS (gage_t), POINTER :: gage

    CALL decimal_to_date(time, date_string, time_string)
    
    CALL this%gages%begin()
    gage => this%gages%current()

    DO WHILE (ASSOCIATED(gage))
       CALL gage%output(date_string, time_string)
       CALL this%gages%next()
       gage => this%gages%current()
    END DO

  END SUBROUTINE gage_manager_output

  ! ----------------------------------------------------------------
  ! SUBROUTINE gage_manager_destroy
  ! ----------------------------------------------------------------
  SUBROUTINE gage_manager_destroy(this)

    IMPLICIT NONE
    CLASS (gage_manager), INTENT(INOUT) :: this
    CALL this%gages%clear()

  END SUBROUTINE gage_manager_destroy


END MODULE gage_module
