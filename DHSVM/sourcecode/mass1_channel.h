/* -------------------------------------------------------------
   file: mass1_channel.h

   ------------------------------------------------------------- */
/* -------------------------------------------------------------
   Battelle Memorial Institute
   Pacific Northwest Laboratory
   ------------------------------------------------------------- */
/* -------------------------------------------------------------
   Created February  8, 2019 by William A. Perkins
   Last Change: 2019-02-15 13:53:02 d3g096
   ------------------------------------------------------------- */

#ifndef _mass1_channel_h_
#define _mass1_channel_h_

#include "DHSVMChannel.h"
#include "Calendar.h"


/* -------------------------------------------------------------
   C API for Fortran routines in MASS1/mass1_dhsvm_api.f90
   ------------------------------------------------------------- */

extern void *mass1_create(char *cfgdir, char *outdir,
                          DATE *start, DATE *end,
                          int pid, int dotemp);

extern void mass1_write_hotstart(void *net, char *fname);

extern void mass1_read_hotstart(void *net, char *fname);

extern void mass1_destroy(void *net);

/* -------------------------------------------------------------
   DHSVM routines for dealing with a MASS1 network
   ------------------------------------------------------------- */

extern void mass1_route_network(void *net, Channel *streams, DATE *todate, int delatt);


#endif
