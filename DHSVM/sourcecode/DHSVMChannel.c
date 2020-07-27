/* -------------------------------------------------------------
   file: DHSVMChannel.c
   ------------------------------------------------------------- */
/* -------------------------------------------------------------
   Battelle Memorial Institute
   Pacific Northwest Laboratory
   ------------------------------------------------------------- */
/* -------------------------------------------------------------
   Created August 30, 1996 by  William A Perkins
   $Id: DHSVMChannel.c, v3.1.2  2013/12/20   Ning Exp $
   ------------------------------------------------------------- */

#include <assert.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <ga.h>
#include "constants.h"
#include "getinit.h"
#include "DHSVMChannel.h"
#include "DHSVMerror.h"
#include "functions.h"
#include "settings.h"
#include "errorhandler.h"
#include "fileio.h"
#include "ParallelDHSVM.h"
#include "ParallelChannel.h"

#ifdef MASS1_CHANNEL
#include "mass1_channel.h"
#endif

#ifdef MASS1_CHANNEL


/* -------------------------------------------------------------
   set_or_read_mass1_met_coeff
   ------------------------------------------------------------- */
static void
set_or_read_mass1_met_coeff(ChannelPtr net, float ltemp,
                            float winda, float windb, float cond,
                            float brunt, float bdepth, char *coeff_file)
{
  ChannelPtr current, cindex;

  /* all segments get the "default" inflow temperature and met
     coefficients */
  for (current = net; current != NULL;
       current = current->next) {
    current->lateral_temp = ltemp;
    current->wind_function_a = winda;
    current->wind_function_b = windb;
    current->conduction = cond;
    current->brunt = brunt;
    current->bed_depth = bdepth;
  }

  /* if a file is specified, read it and set inflow temperature and
     coefficienst only for the segments listed */
  if (coeff_file != NULL) {
    channel_read_mass1_coeff(net, coeff_file);
  }
}

void
write_mass1_met_coeff(ChannelPtr net, char *coeff_file)
{
  ChannelPtr current;
  FILE *out;

  OpenFile(&out, coeff_file, "w", TRUE);
  for (current = net; current != NULL;
       current = current->next) {
    fprintf(out, "%6d %8.2f %8.2f %8.2f %8.2f %8.2f %8.2f\n",
            current->id,
            current->wind_function_a, current->wind_function_b,
            current->conduction, current->brunt,
            current->lateral_temp, current->bed_depth);
  }
  fclose(out);
}
#endif

/* -----------------------------------------------------------------------------
   InitChannel
   Reads stream and road files and builds the networks.
   -------------------------------------------------------------------------- */
void
InitChannel(LISTPTR Input, MAPSIZE *Map, int deltat, CHANNEL *channel,
	    SOILPIX ** SoilMap, int *MaxStreamID, int *MaxRoadID,
            OPTIONSTRUCT *Options, TIMESTRUCT *Time)
{
  int i;
  STRINIENTRY StrEnv[] = {
    {"ROUTING", "STREAM NETWORK FILE", "", ""},
    {"ROUTING", "STREAM MAP FILE", "", ""},
    {"ROUTING", "STREAM CLASS FILE", "", ""},
    {"ROUTING", "RIPARIAN VEG FILE", "", ""},
    {"ROUTING", "ROAD NETWORK FILE", "", "none"},
    {"ROUTING", "ROAD MAP FILE", "", "none"},
    {"ROUTING", "ROAD CLASS FILE", "", "none"},
    {"ROUTING", "MASS1 CONFIGURATION", "", "."},
    {"ROUTING", "MASS1 INFLOW TEMPERATURE", "", "12.0"},
    {"ROUTING", "MASS1 WIND FUNCTION A", "", "0.46"},
    {"ROUTING", "MASS1 WIND FUNCTION B", "", "9.2"},
    {"ROUTING", "MASS1 CONDUCTION COEFFICIENT", "", "0.47"},
    {"ROUTING", "MASS1 BRUNT COEFFICIENT", "", "0.65"},
    {"ROUTING", "MASS1 INTERNAL LONGWAVE", "", "FALSE"},
    {"ROUTING", "MASS1 USE SHADING", "", "TRUE"},
    {"ROUTING", "MASS1 USE BED", "", "FALSE"},
    {"ROUTING", "MASS1 BED DEPTH", "", "2.0"},
    {"ROUTING", "MASS1 MET COEFFICIENT FILE", "", "none"},
    {"ROUTING", "MASS1 MET COEFFICIENT OUTPUT", "", "none"},
    {"ROUTING", "MASS1 QUIET", "", "TRUE"},
    {"ROUTING", "MASS1 GAGE OUTPUT", "", "FALSE"},
    {"ROUTING", "MASS1 PROFILE OUTPUT", "", "FALSE"},
    {NULL, NULL, "", NULL}
  };
#ifdef MASS1_CHANNEL
  char mass1_config_path[BUFSIZE + 1];
  char mass1_out_path[BUFSIZE + 1];
  float mass1_temp, mass1_coeff_a, mass1_coeff_b, mass1_coeff_cond,
    mass1_coeff_brunt, mass1_coeff_bdepth;
  char *coeff_file, *coeff_output;
  ChannelPtr current;

#endif

  if (ParallelRank() == 0) 
    printf("\nInitializing Road/Stream Networks\n");

  /* Read the key-entry pairs from the ROUTING section in the input file */
  for (i = 0; StrEnv[i].SectionName; i++) {
    GetInitString(StrEnv[i].SectionName, StrEnv[i].KeyName, StrEnv[i].Default,
      StrEnv[i].VarStr, (unsigned long)BUFSIZE, Input);
    if (!strncmp(StrEnv[i].KeyName, "RIPARIAN VEG FILE", 6)) {
      if (Options->StreamTemp) {
      if (IsEmptyStr(StrEnv[i].VarStr))
        ReportError(StrEnv[i].KeyName, 51);
      }
    }
    else {
      if (IsEmptyStr(StrEnv[i].VarStr))
      ReportError(StrEnv[i].KeyName, 51);
    }
  }

  channel->stream_class = NULL;
  channel->road_class = NULL;
  channel->streams = NULL;
  channel->roads = NULL;
  channel->stream_map = NULL;
  channel->road_map = NULL;
  channel->mass1_streams = NULL;

  channel_init();
  channel_grid_init(Map->NX, Map->NY);

  if (strncmp(StrEnv[stream_class].VarStr, "none", 4)) {

    if (ParallelRank() == 0) 
      printf("\tReading Stream data\n");

    if ((channel->stream_class =
	 channel_read_classes(StrEnv[stream_class].VarStr, stream_class)) == NULL) {
      ReportError(StrEnv[stream_class].VarStr, 5);
    }
    if ((channel->streams =
	 channel_read_network(StrEnv[stream_network].VarStr,
			      channel->stream_class, MaxStreamID)) == NULL) {
      ReportError(StrEnv[stream_network].VarStr, 5);
    }
    if ((channel->stream_map =
	 channel_grid_read_map(Map, channel->streams,
			       StrEnv[stream_map].VarStr, SoilMap)) == NULL) {
      ReportError(StrEnv[stream_map].VarStr, 5);
    }
    error_handler(ERRHDL_STATUS,
		  "InitChannel: computing stream network routing coefficients");
    channel_routing_parameters(channel->streams, (double) deltat);
  }

#ifdef MASS1_CHANNEL
  if (Options->UseMASS1) {

    /* only the root process creates and uses a MASS1 network */
    
    if (ParallelRank() == 0) {
      if (strncmp(StrEnv[mass1_quiet].VarStr, "TRUE", 4) == 0)
        channel->mass1_quiet = TRUE;
      else if (strncmp(StrEnv[mass1_quiet].VarStr, "FALSE", 5) == 0)
        channel->mass1_quiet = FALSE;
      else
        ReportError(StrEnv[mass1_quiet].KeyName, 51);

      /* flag to turn on/off MASS1 gage output (for debugging) */
      if (strncmp(StrEnv[mass1_gage].VarStr, "TRUE", 4) == 0)
        channel->mass1_do_gage = TRUE;
      else if (strncmp(StrEnv[mass1_gage].VarStr, "FALSE", 5) == 0)
        channel->mass1_do_gage = FALSE;
      else
        ReportError(StrEnv[mass1_gage].KeyName, 51);

      /* flag to turn on/off MASS1 profile output (for debugging) */
      if (strncmp(StrEnv[mass1_prof].VarStr, "TRUE", 4) == 0)
        channel->mass1_do_profile = TRUE;
      else if (strncmp(StrEnv[mass1_prof].VarStr, "FALSE", 5) == 0)
        channel->mass1_do_profile = FALSE;
      else
        ReportError(StrEnv[mass1_prof].KeyName, 51);
      
      if (Options->StreamTemp) {
        if (strncmp(StrEnv[mass1_int_lw].VarStr, "TRUE", 4) == 0)
          channel->mass1_dhsvm_longwave = FALSE;
        else if (strncmp(StrEnv[mass1_int_lw].VarStr, "FALSE", 5) == 0)
          channel->mass1_dhsvm_longwave = TRUE;
        else
          ReportError(StrEnv[mass1_int_lw].KeyName, 51);
        
        if (strncmp(StrEnv[mass1_bed].VarStr, "TRUE", 4) == 0)
          channel->mass1_do_bed = TRUE;
        else if (strncmp(StrEnv[mass1_bed].VarStr, "FALSE", 5) == 0)
          channel->mass1_do_bed = FALSE;
        else
          ReportError(StrEnv[mass1_shading].KeyName, 51);
      }
      
      strncpy(mass1_config_path, StrEnv[mass1_config].VarStr, BUFSIZE+1);
      strncpy(mass1_out_path, ".", BUFSIZE+1);

      printf("Reading MASS1 Configuration from %s\n", mass1_config_path);
      channel->mass1_streams = mass1_create(mass1_config_path, mass1_out_path,
                                            &(Time->Start), &(Time->End),
                                            ParallelRank(), Options->StreamTemp,
                                            channel->mass1_dhsvm_longwave,
                                            channel->mass1_do_bed,
                                            channel->mass1_quiet,
                                            channel->mass1_do_gage,
                                            channel->mass1_do_profile);

      if (Options->StreamTemp) {
        if (!CopyFloat(&mass1_temp, StrEnv[mass1_inflow_temp].VarStr, 1)) {
          ReportError(StrEnv[mass1_inflow_temp].KeyName, 51);
        }
        if (!CopyFloat(&mass1_coeff_a, StrEnv[mass1_wind_a].VarStr, 1)) {
          ReportError(StrEnv[mass1_wind_a].KeyName, 51);
        }
        if (!CopyFloat(&mass1_coeff_b, StrEnv[mass1_wind_b].VarStr, 1)) {
          ReportError(StrEnv[mass1_wind_b].KeyName, 51);
        }
        if (!CopyFloat(&mass1_coeff_cond, StrEnv[mass1_conduction].VarStr, 1)) {
          ReportError(StrEnv[mass1_conduction].KeyName, 51);
        }
        if (!CopyFloat(&mass1_coeff_brunt, StrEnv[mass1_brunt].VarStr, 1)) {
          ReportError(StrEnv[mass1_brunt].KeyName, 51);
        }
        if (!CopyFloat(&mass1_coeff_bdepth, StrEnv[mass1_bed_depth].VarStr, 1)) {
          ReportError(StrEnv[mass1_bed_depth].KeyName, 51);
        }

        if (strncmp(StrEnv[mass1_coeff_file].VarStr, "none", 4))  {
          coeff_file = StrEnv[mass1_coeff_file].VarStr;
        } else {
          coeff_file = NULL;
        }

        if (strncmp(StrEnv[mass1_coeff_output].VarStr, "none", 4))  {
          coeff_output = StrEnv[mass1_coeff_output].VarStr;
	  strncpy(channel->streams_met_coeff_out, coeff_output, BUFSIZE);
        } else {
	  strcpy(channel->streams_met_coeff_out, "");
        }
        
        if (strncmp(StrEnv[mass1_shading].VarStr, "TRUE", 4) == 0)
          channel->mass1_do_shading = TRUE;
        else if (strncmp(StrEnv[mass1_shading].VarStr, "FALSE", 5) == 0)
          channel->mass1_do_shading = FALSE;
        else
          ReportError(StrEnv[mass1_shading].KeyName, 51);

        /* set met coefficients and read from a file, if called for */
        set_or_read_mass1_met_coeff(channel->streams, mass1_temp,
                                    mass1_coeff_a, mass1_coeff_b,
                                    mass1_coeff_cond, mass1_coeff_brunt,
                                    mass1_coeff_bdepth, coeff_file);

        printf("MASS1 Temperature simulation enabled, settings:\n");
        printf("\tMASS1 Inflow Temperature = %.1f\n", mass1_temp);
        printf("\tMASS1 Wind Function A = %.3f\n", mass1_coeff_a);
        printf("\tMASS1 Wind Function B = %.3f\n", mass1_coeff_b);
        printf("\tMASS1 Conduction Coefficient = %.3f\n", mass1_coeff_cond);
        printf("\tMASS1 Brunt Coefficient  =  %.3f\n", mass1_coeff_brunt);
        printf("\tMASS1 Internal Longwave = %s\n",
               (channel->mass1_dhsvm_longwave ? "FALSE" : "TRUE"));
        printf("\tMASS1 Use Shading = %s\n",
               (channel->mass1_do_shading ? "TRUE" : "FALSE"));
        printf("\tMASS1 Use Bed = %s\n",
               (channel->mass1_do_bed ? "TRUE" : "FALSE"));
        printf("\tMASS1 Bed Depth  =  %.3f\n", mass1_coeff_bdepth);
      }
    }
  }
  ParallelBarrier();
#endif

  if (Options->StreamTemp) {
    if (strncmp(StrEnv[riparian_veg].VarStr, "none", 4)) {
      if (ParallelRank() == 0) 
        printf("\tReading channel riparian vegetation params\n");
      channel_read_rveg_param(channel->streams, StrEnv[riparian_veg].VarStr, MaxStreamID);
    }
  }

  if (strncmp(StrEnv[road_class].VarStr, "none", 4)) {

    if (ParallelRank() == 0) 
      printf("\tReading Road data\n");

    if ((channel->road_class =
	 channel_read_classes(StrEnv[road_class].VarStr, road_class) == NULL)) {
      ReportError(StrEnv[road_class].VarStr, 5);
    }
    if ((channel->roads =
	 channel_read_network(StrEnv[road_network].VarStr,
			      channel->road_class, MaxRoadID)) == NULL) {
      ReportError(StrEnv[road_network].VarStr, 5);
    }
    if ((channel->road_map =
	 channel_grid_read_map(Map, channel->roads,
			       StrEnv[road_map].VarStr, SoilMap)) == NULL) {
      ReportError(StrEnv[road_map].VarStr, 5);
    }
    error_handler(ERRHDL_STATUS,
		  "InitChannel: computing road network routing coefficients");
    channel_routing_parameters(channel->roads, (double) deltat);
  }

  ParallelBarrier();

  if (channel->streams != NULL) {
    channel->stream_state_ga = ChannelStateGA(channel->streams);
  }
  if (channel->roads != NULL) {
    channel->road_state_ga = ChannelStateGA(channel->roads);
  }

  ParallelBarrier();
}

/* -------------------------------------------------------------
   InitChannelDump
   ------------------------------------------------------------- */
void InitChannelDump(OPTIONSTRUCT *Options, CHANNEL * channel, 
                     char *DumpPath)
{
  char buffer[NAMESIZE];

  if (ParallelRank() == 0) {
    if (channel->streams != NULL) {
      sprintf(buffer, "%sStream.Flow", DumpPath);
      OpenFile(&(channel->streamout), buffer, "w", TRUE);
      sprintf(buffer, "%sStreamflow.Only", DumpPath);
      OpenFile(&(channel->streamflowout), buffer, "w", TRUE);
      /* output files for John's RBM model */
      if (Options->StreamTemp && !Options->UseMASS1) {
        //inflow to segment
        sprintf(buffer, "%sInflow.Only", DumpPath);
        OpenFile(&(channel->streaminflow), buffer, "w", TRUE);
        // outflow ( redundant but it's a check
        sprintf(buffer, "%sOutflow.Only", DumpPath);
        OpenFile(&(channel->streamoutflow), buffer, "w", TRUE);
        //net incoming short wave
        sprintf(buffer, "%sNSW.Only", DumpPath);
        OpenFile(&(channel->streamNSW), buffer, "w", TRUE);
        // net incoming long wave
        sprintf(buffer, "%sNLW.Only", DumpPath);
        OpenFile(&(channel->streamNLW), buffer, "w", TRUE);
        //Vapor pressure
        sprintf(buffer, "%sVP.Only", DumpPath);
        OpenFile(&(channel->streamVP), buffer, "w", TRUE);
        //wind speed
        sprintf(buffer, "%sWND.Only", DumpPath);
        OpenFile(&(channel->streamWND), buffer, "w", TRUE);
        //air temperature
        sprintf(buffer, "%sATP.Only", DumpPath);
        OpenFile(&(channel->streamATP), buffer, "w", TRUE);
        //melt water in flow
        sprintf(buffer, "%sMelt.Only", DumpPath);
        OpenFile(&(channel->streamMelt), buffer, "w", TRUE);                      
      }

#ifdef MASS1_CHANNEL
      /* Output stream temperature simulated by MASS1, if any */
      if (Options->StreamTemp && Options->UseMASS1) {
        sprintf(buffer, "%sStreamtemp.Only", DumpPath);
        OpenFile(&(channel->streamtempout), buffer, "w", TRUE);
        if (strlen(channel->streams_met_coeff_out) > 0) {
          sprintf(buffer, "%s/%s", DumpPath, channel->streams_met_coeff_out);
          write_mass1_met_coeff(channel->streams, buffer);
        }
      }
#endif
    }
    if (channel->roads != NULL) {
      sprintf(buffer, "%sRoad.Flow", DumpPath);
      OpenFile(&(channel->roadout), buffer, "w", TRUE);
      sprintf(buffer, "%sRoadflow.Only", DumpPath);
      OpenFile(&(channel->roadflowout), buffer, "w", TRUE);

    }
  }

}


/* -------------------------------------------------------------
   ChannelCulvertFlow    
   computes outflow of channel/road network to a grid cell, if it
   contains a sink
   ------------------------------------------------------------- */
double ChannelCulvertFlow(int y, int x, CHANNEL * ChannelData)
{
  if (channel_grid_has_channel(ChannelData->road_map, x, y)) {
    return channel_grid_outflow(ChannelData->road_map, x, y);
  }
  else {
    return 0;
  }
}

/* -------------------------------------------------------------
   RouteChannel
   ------------------------------------------------------------- */
void
RouteChannel(CHANNEL *ChannelData, TIMESTRUCT *Time, MAPSIZE *Map,
             TOPOPIX **TopoMap, SOILPIX **SoilMap, AGGREGATED *Total, 
	     OPTIONSTRUCT *Options, ROADSTRUCT **Network, SOILTABLE *SType, 
             PRECIPPIX **PrecipMap, float Tair, float Rh, SNOWPIX **SnowMap)
{
  int x, y;
  int flag;
  char buffer[32];
  float CulvertFlow;
  float temp;
  
  /* set flag to true if it's time to output channel network results */
  SPrintDate(&(Time->Current), buffer);
  flag = IsEqualTime(&(Time->Current), &(Time->Start));

  /* ParallelBarrier(); */

  /* give any surface water to roads w/o sinks */
  for (y = 0; y < Map->NY; y++) {
    for (x = 0; x < Map->NX; x++) {
      if (INBASIN(TopoMap[y][x].Mask)) {
        if (channel_grid_has_channel(ChannelData->road_map, x, y) && 
            !channel_grid_has_sink(ChannelData->road_map, x, y)) {	/* road w/o sink */
          SoilMap[y][x].RoadInt += SoilMap[y][x].IExcess; 
          channel_grid_inc_inflow(ChannelData->road_map, x, y, SoilMap[y][x].IExcess * Map->DX * Map->DY);
          SoilMap[y][x].IExcess = 0.0f;
        }
      }
    }
  }

  if (ChannelData->roads != NULL) {

    /* collect lateral inflow from all processes */
    ChannelGatherLateralInflow(ChannelData->roads, ChannelData->road_state_ga);

    /* Just the root process routes the road network and saves the results */
    if (ParallelRank() == 0) {
      channel_route_network(ChannelData->roads, Time->Dt);

      channel_save_outflow_text(buffer, ChannelData->roads,
                                ChannelData->roadout, ChannelData->roadflowout, flag);
    }

    /* all processes get a copy of the routing results */
    ChannelDistributeState(ChannelData->roads, ChannelData->road_state_ga);
  }
    
  /* add culvert outflow to surface water */
  Total->CulvertReturnFlow = 0.0;
  for (y = 0; y < Map->NY; y++) {
    for (x = 0; x < Map->NX; x++) {
      if (INBASIN(TopoMap[y][x].Mask)) {
        CulvertFlow = ChannelCulvertFlow(y, x, ChannelData);
        CulvertFlow /= Map->DX * Map->DY;
		
        /* CulvertFlow = (CulvertFlow > 0.0) ? CulvertFlow : 0.0; */
        if (channel_grid_has_channel(ChannelData->stream_map, x, y)) {
          channel_grid_inc_inflow(ChannelData->stream_map, x, y,
                                  (SoilMap[y][x].IExcess + CulvertFlow) * Map->DX * Map->DY);
          if (SnowMap[y][x].Outflow > SoilMap[y][x].IExcess)
            temp = SoilMap[y][x].IExcess;
          else
            temp = SnowMap[y][x].Outflow;
          channel_grid_inc_melt(ChannelData->stream_map, x, y, temp * Map->DX * Map->DY);                                                                                  
          SoilMap[y][x].ChannelInt += SoilMap[y][x].IExcess;
          Total->CulvertToChannel += CulvertFlow;
          SoilMap[y][x].IExcess = 0.0f;
        }
        else {
          SoilMap[y][x].IExcess += CulvertFlow;
          Total->CulvertReturnFlow += CulvertFlow;
        }
      }
    }
  }
  
  /* route stream channels */
  if (ChannelData->streams != NULL) {
    
    /* collect lateral inflow from all processes */
    ChannelGatherLateralInflow(ChannelData->streams, ChannelData->stream_state_ga);

    /* Only the root process routes the stream network and saves the results */

    if (ParallelRank() == 0) {

#ifdef MASS1_CHANNEL
      if (Options->UseMASS1) {
        mass1_route_network(ChannelData->mass1_streams, ChannelData->streams,
                            &(Time->Current), Time->Dt, Options->StreamTemp,
                            ChannelData->mass1_do_shading);
      } else {
        channel_route_network(ChannelData->streams, Time->Dt);
      }
#else
      channel_route_network(ChannelData->streams, Time->Dt);
#endif
    
      channel_save_outflow_text(buffer, ChannelData->streams,
                                ChannelData->streamout,
                                ChannelData->streamflowout, flag);
      /* save parameters for John's RBM model */
      if (Options->StreamTemp && !Options->UseMASS1)
        channel_save_outflow_text_cplmt(Time, buffer,ChannelData->streams,ChannelData, flag);
      if (Options->StreamTemp && Options->UseMASS1) {
        channel_save_temperature_text(buffer, 
                                      ChannelData->streams,
                                      ChannelData->streamtempout,
                                      flag);
      }
    }

    ChannelDistributeState(ChannelData->streams, ChannelData->stream_state_ga);
    
  }
  ParallelBarrier();
}

/* -------------------------------------------------------------
   ChannelCut
   computes necessary parameters for cell storage adjustment from
   channel/road dimensions
   ------------------------------------------------------------- */
void ChannelCut(int y, int x, CHANNEL * ChannelData, ROADSTRUCT * Network)
{
  float bank_height = 0.0;
  float cut_area = 0.0;

  if (channel_grid_has_channel(ChannelData->stream_map, x, y)) {
    bank_height = channel_grid_cell_bankht(ChannelData->stream_map, x, y);
    cut_area = channel_grid_cell_width(ChannelData->stream_map, x, y) * 
      channel_grid_cell_length(ChannelData->stream_map, x, y);
  }
  else if (channel_grid_has_channel(ChannelData->road_map, x, y)) {
    bank_height = channel_grid_cell_bankht(ChannelData->road_map, x, y);
    cut_area = channel_grid_cell_width(ChannelData->road_map, x, y) * 
      channel_grid_cell_length(ChannelData->road_map, x, y);
  }
  Network->Area = cut_area;
  Network->BankHeight = bank_height;
}

/* -------------------------------------------------------------
   ChannelFraction
   This computes the (sub)surface flow fraction for a road
   ------------------------------------------------------------- */
uchar ChannelFraction(TOPOPIX * topo, ChannelMapRec * rds)
{
  float effective_width = 0;
  float total_width;
  float sine, cosine;
  ChannelMapRec *r;
  float fract = 0.0;

  if (rds == NULL) {
    return 0;
  }
  cosine = cos(topo->Aspect);
  sine = sin(topo->Aspect);
  total_width = topo->FlowGrad / topo->Slope;
  effective_width = 0.0;

  for (r = rds; r != NULL; r = r->next) {
    effective_width += r->length * sin(fabs(topo->Aspect - r->aspect));
  }
  fract = effective_width / total_width * 255.0;
  fract = (fract > 255.0 ? 255.0 : floor(fract + 0.5));

  return (uchar) fract;
}

/* -------------------------------------------------------------
   DestroyChannel
   This completely destroys channel network data.
   ------------------------------------------------------------- */
void
DestroyChannel(OPTIONSTRUCT *Options, MAPSIZE *Map, CHANNEL *channel)
{
  ParallelBarrier();

  if (channel->streams != NULL) {
    channel_free_classes(channel->stream_class);
    channel_free_network(channel->streams);
    channel_grid_free_map(Map, channel->stream_map);
    GA_Destroy(channel->stream_state_ga);
    if (ParallelRank() == 0) {
      if (channel->streamout != NULL) fclose(channel->streamout);
      if (channel->streamflowout != NULL) fclose(channel->streamflowout);
      if (channel->streamtempout != NULL) fclose(channel->streamtempout);
    }    
  }
  if (channel->roads != NULL) {
    channel_free_classes(channel->road_class);
    channel_free_network(channel->roads);
    channel_grid_free_map(Map, channel->road_map);
    GA_Destroy(channel->road_state_ga);
    if (ParallelRank() == 0) {
      if (channel->roadout != NULL) fclose(channel->roadout);
      if (channel->roadflowout != NULL) fclose(channel->roadflowout);
    }    
  }
#ifdef MASS1_CHANNEL
  if (Options->UseMASS1) {
    if (ParallelRank() == 0) {
      mass1_destroy(channel->mass1_streams);
    }
  }
#endif

}
