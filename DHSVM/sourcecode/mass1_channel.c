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
 * LAST CHANGE: 2019-04-10 09:16:37 d3g096
 * COMMENTS:
 */

#include "mass1_channel.h"

/* -------------------------------------------------------------
   routines in mass1lib that are only used here
   ------------------------------------------------------------- */

extern void mass1_route(void *net, DATE *ddate);
extern void mass1_update_latq(void *net, int id, float latq, DATE *ddate);
extern void mass1_update_latt(void *net, int id, float latt, DATE *ddate);
extern void mass1_update_met(void *net, int id,
                             float airtemp, float rh,
                             float windspeed, float swradiation,
                             DATE *ddate);
extern void mass1_update_met_coeff(void *net, int id,
                                   float a, float b, float Ccond, float brunt);
extern double mass1_link_outflow(void *net, int id);
extern double mass1_link_inflow(void *net, int id);

extern double mass1_link_inflow_temp(void *net, int id);
extern double mass1_link_outflow_temp(void *net, int id);


/* -------------------------------------------------------------
   mass1_set_coeffients
   ------------------------------------------------------------- */
void
mass1_set_coeffients(void *net, Channel *streams)
{
  ChannelPtr current;

  for (current = streams; current != NULL; current = current->next) {
    mass1_update_met_coeff(net, current->id,
                           current->wind_function_a,
                           current->wind_function_b,
                           current->conduction,
                           current->brunt);
  }
}

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
 * @param dotemp Is temperature simulation enabled?
 */
void
mass1_route_network(void *net, Channel *streams, DATE *todate, int deltat, int dotemp)
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

    if (dotemp) {
      /* update lateral inflow temperatures */
      mass1_update_latt(net, id, current->inflow_temp, todate);

      /* update met */

      /* 
      mass1_update_met(net, id,
                       current->ATP, current->RH/100.0,
                       current->WND, current->NSW,
                       todate);
      */
    }
  }

  /* route the network */

  mass1_route(net, todate);

  /* collect computed segment inflow/outflow */

  for (current = streams; current != NULL; current = current->next) {
    id = current->id;
    current->inflow = mass1_link_inflow(net, id)*deltat;
    current->outflow = mass1_link_outflow(net, id)*deltat;
    if (dotemp) {
      current->inflow_temp = mass1_link_inflow_temp(net, id);
      current->outflow_temp = mass1_link_outflow_temp(net, id);
    }
  }
}
