! ----------------------------------------------------------------
! MODULE mass1_dhsvm_module
! ----------------------------------------------------------------
MODULE mass1_dhsvm_module

  USE iso_c_binding
  USE utility
  USE julian
  USE date_time
  USE time_series
  USE network_module
  USE link_module
  USE bc_module

  IMPLICIT NONE

  ! ----------------------------------------------------------------
  ! TYPE DHSVM_date
  !
  ! Corresponds to the DATE struct in DHSVM
  ! ----------------------------------------------------------------
  TYPE, PUBLIC, BIND(c) :: DHSVM_date
     INTEGER(KIND=C_INT) :: year
     INTEGER(KIND=C_INT) :: month
     INTEGER(KIND=C_INT) :: day
     INTEGER(KIND=C_INT) :: hour
     INTEGER(KIND=C_INT) :: min
     INTEGER(KIND=C_INT) :: sec
     INTEGER(KIND=C_INT) :: jday     ! day of year
     REAL(KIND=C_DOUBLE) :: julian   ! julian day?
  END type DHSVM_date

  TYPE, PUBLIC :: DHSVM_network
     TYPE (link_ptr), ALLOCATABLE :: link_lookup(:)
     TYPE (network), POINTER :: net
  END type DHSVM_network

CONTAINS

  ! ----------------------------------------------------------------
  ! DOUBLE PRECISION FUNCTION dhsvm_to_decimal
  ! ----------------------------------------------------------------
  DOUBLE PRECISION FUNCTION dhsvm_to_decimal(ddate) 

    IMPLICIT NONE
    TYPE (DHSVM_date), INTENT(IN) :: ddate
    DOUBLE PRECISION :: ss

    ss = DBLE(ddate%sec)

    dhsvm_to_decimal = juldays(&
         &ddate%month, ddate%day, ddate%year, &
         &ddate%hour, ddate%min, ss)
  END FUNCTION dhsvm_to_decimal

  ! ----------------------------------------------------------------
  ! SUBROUTINE f2cstring
  ! ----------------------------------------------------------------
  SUBROUTINE f2cstring(fstr, cstr)
    IMPLICIT NONE
    CHARACTER (LEN=*), INTENT(IN) :: fstr
    CHARACTER(KIND=c_char), INTENT(OUT) :: cstr(*)
    INTEGER :: i, len
    len = len_trim(fstr)
    DO i = 1, len
       cstr(i) = fstr(i:i)
    END DO
    cstr(len+1) = C_NULL_CHAR
  END SUBROUTINE f2cstring

  ! ----------------------------------------------------------------
  ! SUBROUTINE c2fstring
  ! This assumes some dangerous things about cstr. 
  ! ----------------------------------------------------------------
  SUBROUTINE c2fstring(cstr, fstr)
    IMPLICIT NONE
    TYPE (c_ptr), VALUE :: cstr
    CHARACTER(LEN=1, KIND=c_char), DIMENSION(:), POINTER :: p_chars
    CHARACTER (LEN=*), INTENT(OUT) :: fstr
    INTEGER :: i

    IF (.NOT. C_ASSOCIATED(cstr)) THEN
       FSTR = " "
    ELSE
       CALL C_F_POINTER(cstr, p_chars, [HUGE(0)])
       DO i = 1, LEN(fstr)
          IF (p_chars(i) .EQ. C_NULL_CHAR) EXIT
          fstr(i:i) = p_chars(i)
       END DO
       IF (i .LE. LEN(fstr)) fstr(i:) = " "
    END IF
       
  END SUBROUTINE c2fstring


  ! ----------------------------------------------------------------
  ! SUBROUTINE mass1_initialize
  ! ----------------------------------------------------------------
  SUBROUTINE mass1_initialize(dnet, cfgdir, outdir, start, end, dotemp)

    IMPLICIT NONE
    TYPE (DHSVM_network), INTENT(INOUT) :: dnet
    CHARACTER (LEN=*), INTENT(IN) :: cfgdir, outdir
    TYPE (DHSVM_date), INTENT(INOUT) :: start, end
    LOGICAL, INTENT(IN) :: dotemp

    CHARACTER (LEN=1024) :: path, msg
    INTEGER :: id, n

    CLASS (link_t), POINTER :: link
    CLASS (simple_bc_t), POINTER :: latbc
    DOUBLE PRECISION, PARAMETER :: zero(5) = 0.0

    utility_error_iounit = 11
    utility_status_iounit = 99

    CALL date_time_flags()
    CALL time_series_module_init()

    ! open the status file - this file records progress through the
    ! input stream and errors
    !
    IF (LEN_TRIM(outdir) .GT. 0) THEN
       path = TRIM(outdir) // "/mass1-status.out"
       CALL open_new(path, utility_status_iounit)
       path = TRIM(outdir) // "/mass1-error.out"
       CALL open_new(path, utility_error_iounit)
    ELSE 
       CALL open_new('mass1-status.out', utility_status_iounit)
       CALL open_new('mass1-warning.out', utility_error_iounit)
    END IF

    CALL banner()

    dnet%net = network()
    CALL dnet%net%read(cfgdir)

    ASSOCIATE (cfg => dnet%net%config)
      cfg%time%begin = dhsvm_to_decimal(start)
      cfg%time%end = dhsvm_to_decimal(end)
      cfg%time%time = cfg%time%begin
      cfg%do_temp = dotemp
      cfg%temp_diffusion = .TRUE.
      cfg%temp_exchange = .TRUE.
      cfg%met_required = cfg%do_temp
    END ASSOCIATE

    ! assume link id's are generally contiguous, or at least not too
    ! big, make a lookup table so we can easily find links later;
    ! also, initialize a lateral inflow table for each link, if
    ! necessary
    n = dnet%net%links%maxid()
    ALLOCATE(dnet%link_lookup(n))
    ASSOCIATE (links => dnet%net%links%links, bcs => dnet%net%bcs%bcs)
      CALL links%begin();
      link =>links%current();

      DO WHILE (ASSOCIATED(link))
         id = link%id
         dnet%link_lookup(id)%p => link
         IF (.NOT. ASSOCIATED(link%latbc)) THEN
            ALLOCATE(latbc)
            latbc%tbl => time_series_alloc(id, 1, 1)
            latbc%tbl%limit_mode = TS_LIMIT_FLAT
            CALL time_series_push(latbc%tbl, dnet%net%config%time%begin, zero)
            CALL bcs%push(LATFLOW_BC_TYPE, latbc)
            link%latbc => latbc
            NULLIFY(latbc)
         ELSE
            WRITE (msg, *) 'link ', id, ': existing lateral inflow table ',&
                 &'may cause problems'
            CALL error_message(msg)
         END IF
         CALL links%next();
         link =>links%current();
      END DO
    END ASSOCIATE

    CALL dnet%net%initialize()

  END SUBROUTINE mass1_initialize

  
END MODULE mass1_dhsvm_module