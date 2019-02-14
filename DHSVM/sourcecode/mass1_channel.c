/*
 * SUMMARY:      mass1_channel.c
 * USAGE:        Part of DHSVM
 *
 * AUTHOR:       William A. Perkins
 * ORG:          Pacific NW National Laboratory
 * E-MAIL:       william.perkins@pnnl.gov
 * ORIG-DATE:    February 2019
 * DESCRIPTION:  
 *
 * DESCRIP-END.cd
 * FUNCTIONS:    
 * LAST CHANGE: 2019-02-14 14:43:47 d3g096
 * COMMENTS:
 */

#include "mass1_channel.h"

/* -------------------------------------------------------------
   routines in mass1lib that are only used here
   ------------------------------------------------------------- */

extern void mass1_route(void *net, DATE *ddate);
extern void mass1_update_latq(void *net, int id, float latq, DATE *ddate);
extern double mass1_link_outflow(void *net, int id);
extern double mass1_link_inflow(void *net, int id);


/* -------------------------------------------------------------
   mass1_route_network
   ------------------------------------------------------------- */
/** 
 * 
 * 
 * @param net MASS1 channel network pointer
 * @param streams DHSVM channel network head pointer

 * @param todate Date/time to which the MASS1 simulation time is to be
 *      advanced (current DHSVM simulation time)
 * @param deltat DHSVM simulation time step (seconds)
 */
void
mass1_route_network(void *net, Channel *streams, DATE *todate, int deltat)
{
  Channel *current;
  int id;
  float q;

  /* assign collected lateral inflow to each segment */

  for (current = streams; current != NULL; current = current->next) {
    id = current->id;
    /* at this point lateral_inflow is a volume, make it a rate by
       dividing by the time step */
    q = current->lateral_inflow/deltat;
    /* FIXME: make sure q dimensions are correct */
    mass1_update_latq(net, id, q, todate);
  }

  /* route the network */

  mass1_route(net, todate);

  /* collect computed segment inflow/outflow */

  for (current = streams; current != NULL; current = current->next) {
    id = current->id;
    current->inflow = mass1_link_inflow(net, id)*deltat;
    current->outflow = mass1_link_outflow(net, id)*deltat;
  }
}
