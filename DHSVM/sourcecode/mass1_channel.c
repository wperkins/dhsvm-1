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
 * LAST CHANGE: 2019-02-11 10:04:19 d3g096
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
void
mass1_route_network(void *net, Channel *streams, DATE *todate)
{
  Channel *current;
  int id;
  float q;

  /* assign collected lateral inflow to each segment */

  for (current = streams; current != NULL; current = current->next) {
    id = current->id;
    q = current->lateral_inflow;
    /* FIXME: make sure q dimensions are correct */
    mass1_update_latq(net, id, q, todate);
  }

  /* route the network */

  mass1_route(net, todate);

  /* collect computed segment inflow/outflow */

  for (current = streams; current != NULL; current = current->next) {
    id = current->id;
    current->inflow = mass1_link_inflow(net, id);
    current->outflow = mass1_link_outflow(net, id);
  }
}
