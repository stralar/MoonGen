/*****************************************************************************
 *   main.c - the body for CRUDE
 *
 *   Copyright (C) 1999 Juha Laine and Sampo Saaristo
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 *   Authors:      Juha Laine     <james@cs.tut.fi>
 *                 Sampo Saaristo <sambo@cc.tut.fi>
 *
 *****************************************************************************/
#include <config.h>
#include <rude.h>

#include <stdlib.h>
#include <stdio.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sched.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <limits.h>


/*
 * Private struct for each flow of runtime statistics
 */
struct flow_stat {
  unsigned long flowid;
  unsigned long seqmin, seq;  /* Seq number of the first and current packets */
  unsigned long rec;          /* Number of received packets */
  unsigned long oos;          /* Number of packets out of sequence */
  long long js_sec;           /* Jitter sum of seconds */
  long long js_usec;          /* Jitter sum of microsseconds */
  long long ds_sec;           /* Delay sum of seconds */
  long long ds_usec;          /* Delay sum of microsseconds */
  long last_tx_sec;
  long last_tx_usec;
  long last_rx_sec;
  long last_rx_usec;
  long last_delay_sec;
  long last_delay_usec;
  long first_rx_sec;
  long first_rx_usec;
  long max_jitter_sec;
  long max_jitter_usec;
  unsigned long long s_size;  /* Sum of all packet sizes */
};


/*
 * Function prototypes
 */
static void usage(char *);
static int  make_conn(unsigned short, char *);
static int  decode_file(void);
static int  runtime_stats(unsigned short, unsigned long);
void        print_stats(void);
static int  rec_to_file(unsigned short,unsigned long);
static int  rec_n_print(unsigned short,unsigned long);
void        crude_handler(int);


/*
 * Global variables
 */
int main_socket         = 0;     /* The socket to listen to                  */
int main_file           = 0;     /* File to read from/to write to            */
unsigned long pkt_count = 0;     /* Counter for received/processed packets   */
struct flow_stat *flows = NULL;  /* List of flows for runtime statistics  */
int nflows              = 0;


int main(int argc, char **argv)
{  
  extern char *optarg;
  extern int  optind, opterr, optopt, errno;

  char *ifipadd       = NULL;    /* pointer to interface IP address */
  unsigned short port = 10001;   /* default UDP port number         */
  long w_num          = 0;       /* # pkts to capture. 0=unlimited  */
  int priority        = 0;
  uid_t user_id       = getuid();
  int  cmd_char       = 0;
  int  retval         = 0;
  long temp1          = 0;
  int ps_flag         = 0;
  struct sigaction action;
  struct sched_param p;
  char *sptr, *eptr;
  struct flow_stat *newflows;

  printf("crude version %s, Copyright (C) 1999 Juha Laine and Sampo Saaristo\n"
	 "crude comes with ABSOLUTELY NO WARRANTY!\n"
	 "This is free software, and you are welcome to redistribute it\n"
	 "under GNU GENERAL PUBLIC LICENSE Version 2.\n",VERSION);

  while((retval >= 0) &&
	((cmd_char = getopt(argc,argv,"hvd:p:i:l:P:n:s:")) != EOF)){
    switch(cmd_char){
    case 'v':
      if((optind == 2) && (argc == 2)){
	printf("crude version is %s\n",VERSION);
	retval = -1;
      } else {
	RUDEBUG1("crude: invalid commandline arguments!\n");
	retval = -2;
      }
      break;

    case 'h':
      if((optind == 2) && (argc == 2)){
	usage(argv[0]);
	retval = -1;
      } else {
	RUDEBUG1("crude: invalid commandline arguments!\n");
	retval = -2;
      }
      break;

    case 'd':
      if((optind == 3) && (argc == 3) && (optarg != NULL)){
	if((main_file = open(optarg, O_RDONLY, 0)) < 0){
	  RUDEBUG1("crude: couldn't open file %s: %s\n",optarg,strerror(errno));
	  retval = -3;
	} else {
	  retval = 1;
	}
      } else {
	RUDEBUG1("crude: invalid commandline arguments!\n");
	retval = -2;
      }
      break;

    case 'p':
      if(optarg != NULL){
	errno = 0;
	temp1 = strtol((const char *)optarg,NULL,0);
	if(errno != 0){
	  RUDEBUG1("crude: '-p' number format error: %s\n",strerror(errno));
	  retval = -4;
	} else if((temp1 < 1025) || (temp1 > 65535)){
	  RUDEBUG1("crude: port must be  between 1025-65535!\n");
	  retval = -4;
	} else {
	  port = temp1;
	  retval += 2;
	}
      } else {
	RUDEBUG1("crude: invalid commandline arguments!\n");
	retval = -2;
      }
      break;

    case 'i':
      if(optarg != NULL){

	ifipadd = argv[(optind-1)];
	retval += 4;
      } else {
	RUDEBUG1("crude: invalid commandline arguments!\n");
	retval = -2;
      }
      break;

    case 'l':
      if(optarg != NULL){
	if((main_file = open(optarg, O_WRONLY|O_CREAT|O_TRUNC, 0644)) < 0){
	  RUDEBUG1("crude: couldn't open file %s: %s\n",optarg,strerror(errno));
	  retval = -5;
	} else {
	  retval += 8;
	}
      } else {
	RUDEBUG1("crude: invalid commandline arguments!\n");
	retval = -2;
      }
      break;

    case 'P':
     if(optarg != NULL){
   priority = atoi(optarg);
   if((priority < 1) || (priority > 90)){
      fprintf(stderr,"crude: priority must be between 1 to 90\n");
      retval = -2;
   }
   if(user_id != 0){
      fprintf(stderr,"crude: must be root to set the priority level\n");
      retval = -2;
   }
      } else {
   RUDEBUG1("crude: invalid commandline arguments!\n");
   retval = -2;
   }
   break;

    case 'n':
      if(optarg != NULL){
	errno = 0;
	w_num = strtol((const char *)optarg,NULL,0);
	if(errno != 0){
	  RUDEBUG1("crude: '-w' number format error: %s\n",strerror(errno));
	  retval = -6;
	} else if(w_num <= 0){
	  RUDEBUG1("crude: # of logged packets must be > 0!\n");
	  retval = -6;
	} else {
	  retval += 16;
	}
      } else {
	RUDEBUG1("crude: invalid commandline arguments!\n");
	retval = -2;
      }
      break;

    case 's':
      if(optarg != NULL){
   sptr = optarg;
   do {
     newflows = realloc(flows, (nflows + 1) * sizeof(struct flow_stat));
     if (newflows == NULL) {
       RUDEBUG1("crude: failed to allocate memory for statistics!\n");
       retval = -6;
       break;
     }
     flows = newflows;
     flows[nflows].flowid = strtoul(sptr, &eptr, 10);
     if (eptr == sptr || flows[nflows].flowid == ULONG_MAX) {
       RUDEBUG1("crude: error reading flow IDs!\n");
       retval = -6;
       break;
     }
     if (*eptr && *eptr != ',') {
       RUDEBUG1("crude: flow IDs must be separated by a comma!\n");
       retval = -6;
       break;
     }
     sptr = eptr + 1;
     flows[nflows].rec = 0;
     flows[nflows].oos = 0;
     flows[nflows].seq = ULONG_MAX;
     flows[nflows].seqmin = ULONG_MAX;
     flows[nflows].js_sec = 0;
     flows[nflows].js_usec = 0;
     flows[nflows].ds_sec = 0;
     flows[nflows].ds_usec = 0;
     flows[nflows].s_size = 0;
     flows[nflows].last_delay_sec = 0;
     flows[nflows].last_delay_usec = 0;
     flows[nflows].max_jitter_sec = 0;
     flows[nflows].max_jitter_usec = 0;
     /* The other fields are initialized when the first packet arrives */
     nflows++;
   } while (*eptr);
      } else {
	RUDEBUG1("crude: invalid commandline arguments!\n");
	retval = -2;
      }
      break;

    default:
      usage(argv[0]);
      retval = -1;
      break;
    }
  }

  /* (if retval < 0 -> ERROR or/and EXIT IMMEDIATELY) */
  if(retval < 0){ goto crude_exit; }
 
  /*
   * If this process is owned by root we can do some tricks to
   * improve the performance... (the -P option)
   */
  if((user_id == 0) && (priority > 0)){
    /* Try to lock the memory to avoid paging delays */
    if(mlockall(MCL_CURRENT | MCL_FUTURE) < 0){
      RUDEBUG1("crude: memory lock failed: %s\n", strerror(errno));
    }

    /* Switch to Round-Robin-Real-Time Scheduling */
    p.sched_priority = priority;
    if(sched_setscheduler(0, SCHED_RR, &p) < 0){
      RUDEBUG1("crude: sched_setscheduler() failed: %s\n",strerror(errno));
      retval = -1;
      goto crude_exit;
    }
    RUDEBUG7("crude: program priority set to %d\n", p.sched_priority);
  }                                                                             
 
  /* Activate the signal handler(s) */
  memset(&action, 0, sizeof(struct sigaction));
  action.sa_handler = crude_handler;
  if(sigaction(SIGINT,&action,NULL)){
    RUDEBUG1("crude: signal SIGINT handler failure!\n");
    retval = -7;
    goto crude_exit;
  }

  if(retval == 1){
    retval = decode_file();
  } else {
    if((main_socket=make_conn(port,ifipadd)) < 0){
      RUDEBUG1("crude: couldn't create socket!\n");
      retval = -8;
    } else {
      if (nflows > 0){ retval = runtime_stats(port,w_num); }
      else if(main_file > 0){ retval = rec_to_file(port,w_num); }
      else { retval = rec_n_print(port,w_num); }
    }
  }

 crude_exit:
  if (retval >= 0 && nflows > 0) { ps_flag = 1; }
  /*
   * Restore the tweaked settings...
   */
  if((user_id == 0) && (priority > 0)){
    /* Restore the program priority */
    p.sched_priority = 0;
    if(sched_setscheduler(0, SCHED_OTHER, &p) < 0){
      RUDEBUG1("crude: program priority restoring failed: %s\n",
               strerror(errno));
      retval = -1;
    } else {
      RUDEBUG7("crude: program priority restored\n");
    }

    /* Release the locked memory */
    munlockall();
  }                                                                             

  if(ps_flag){ print_stats(); }
  if(main_file > 0){ close(main_file); }
  if(main_socket > 0){ close(main_socket); }
  if(flows){free(flows); }
  exit(retval);
}


/*
 * usage() - print help and usage information
 */
static void usage(char *name)
{
  printf("\nusage: %s -h | -v | -d file | "
	 "[-p port] [-i addr] [-l file] [-n #]\n\n"
	 "\t-h           = print (this) short help and usage information\n"
	 "\t-v           = print the version number and exit\n"
	 "\t-d file      = decode the file to stdout\n"
	 "\t-p port      = port to listen to\n"
	 "\t-i addr      = numeric IP addres for the interface to listen to\n"
	 "\t-l file      = direct undecoded output to file (fastest method!)\n"
	 "\t               default is to decode the output to stdout\n"
    "\t-P priority  = process realtime priority {1-90}\n\n"
	 "\t-s #[,# ...] = don't record: get runtime stats for specified flows\n"
	 "\t-n #         = exit automatically after # packets has been logged.\n"
	 "\t               use CTRL+C to exit the program otherwise\n\n", name);
}


/*
 * crude_handler() - simple signal handler function
 */
void crude_handler(int value)
{
  struct sched_param pri;
  RUDEBUG7("\ncrude: SIGNAL caught - exiting...\n");
 
  /* Check & restore process priority */
  if((getuid() == 0) && (sched_getscheduler(0) != SCHED_OTHER)){
    pri.sched_priority = 0;
    if(sched_setscheduler(0, SCHED_OTHER, &pri) < 0){
      RUDEBUG1("crude_handler: crude priority failure: %s\n",strerror(errno));
    } else {
      RUDEBUG7("crude_handler: crude priority restored\n");
    }
  }                                                                             

  if(nflows > 0){ print_stats(); }
  if(main_file > 0){ close(main_file); }
  if(main_socket > 0){ close(main_socket); }
  RUDEBUG1("\ncrude: captured/processed %lu packets\n", pkt_count);
  exit(0);
}


/*
 * make_conn()   - make the required connection(s)
 */
static int make_conn(unsigned short port, char *ifaddr)
{
  struct sockaddr our_addr;
  unsigned long   our_ip;
  int             our_sock;

  memset(&our_addr, 0, sizeof(struct sockaddr));
  ((struct sockaddr_in*)&our_addr)->sin_family = AF_INET;
  ((struct sockaddr_in*)&our_addr)->sin_port = htons(port);

  if((ifaddr == NULL) || (strlen(ifaddr) == 0)){
    ((struct sockaddr_in*)&our_addr)->sin_addr.s_addr = htonl(INADDR_ANY);
  } else if((our_ip=inet_addr(ifaddr)) != -1){
    ((struct sockaddr_in*)&our_addr)->sin_addr.s_addr = htonl(our_ip);
  } else {
    RUDEBUG1("crude: invalid interface address %s !\n",ifaddr);
    return -1;
  }

  if((our_sock=socket(AF_INET,SOCK_DGRAM,0)) < 0){
    RUDEBUG1("crude: socket() failed: %s\n", strerror(errno));
    return -2;
  }

  if(bind(our_sock, &our_addr, sizeof(struct sockaddr)) < 0){
    RUDEBUG1("crude: bind() failed: %s\n", strerror(errno));
    close(our_sock);
    return -3;
  }

  return our_sock;
}


/*
 * decode_file() - read the file and print the statistics to stdout in
 *                 human readable form
 */
static int decode_file(void)
{
  struct udp_data *ptr1   = NULL;
  struct crude_struct *ptr2 = NULL;
  char *buffer            = NULL;
  int buf_len             = 0;
  struct in_addr s_add,d_add;
  char str1[16],str2[16];

  /* Allocate memory for the small buffer */
  buf_len = (sizeof(struct udp_data) + sizeof(struct crude_struct));
  if((buffer=(char *)malloc(buf_len)) == NULL){
    RUDEBUG1("crude: couldn't allocate memory: %s\n", strerror(errno));
    return -10;
  }

  memset(str1,0,16);
  memset(str2,0,16);

  while(read(main_file,buffer,buf_len) > 0){
    pkt_count++;
    ptr1 = (struct udp_data*)buffer;
    ptr2 = (struct crude_struct*)(buffer + sizeof(struct udp_data));
    s_add.s_addr = ptr2->src_addr;
    d_add.s_addr = ptr1->dest_addr;
    strncpy(str1,inet_ntoa(s_add),15);
    strncpy(str2,inet_ntoa(d_add),15);
    printf("ID=%lu SEQ=%lu SRC=%s:%hu DST=%s:%hu "
	   "Tx=%ld.%06ld Rx=%ld.%06ld SIZE=%ld\n",
	   (unsigned long)ntohl(ptr1->flow_id),
	   (unsigned long)ntohl(ptr1->sequence_number),
	   str1, ntohs(ptr2->src_port),
	   str2, ntohs(ptr2->dest_port),
	   (unsigned long)ntohl(ptr1->tx_time_seconds),
	   (unsigned long)ntohl(ptr1->tx_time_useconds),
	   (unsigned long)ntohl(ptr2->rx_time_seconds),
	   (unsigned long)ntohl(ptr2->rx_time_useconds),
	   (long)ntohl(ptr2->pkt_size));
  }

  if(errno){ RUDEBUG1("crude: read failed: %s\n", strerror(errno)); }
  free(buffer);
  RUDEBUG1("crude: captured/processed %lu packets\n", pkt_count);
  return 0;
}


/*
 * runtime_stats() - don't record: gather statistics at runtime...
 * This routine 
 */
static int runtime_stats(unsigned short port, unsigned long limit)
{
  long               rec_bytes = 0;     /* Bytes read            */
  int                wri_bytes = 0;     /* Bytes written         */
  int                src_len = sizeof(struct sockaddr_in);
  struct sockaddr_in src_addr;
  struct timeval     time1;
  char buffer[PMAXSIZE];
  struct udp_data *data = (struct udp_data *) buffer;
  int i;
  struct flow_stat *fsp;
  unsigned long seq;
  long tx_s;
  long tx_us;
  unsigned long flowid;                                                        
  long delay_s;
  long delay_us;
  long jitter_s;
  long jitter_us;

  /* Initialize some variables */
  memset(buffer,0,PMAXSIZE);
  
  while(1){
    rec_bytes = recvfrom(main_socket, buffer, PMAXSIZE, 0,
			 (struct sockaddr *)&src_addr, &src_len);
    if(rec_bytes <= 0){
      RUDEBUG1("crude: error when receiving packet: %s\n",strerror(errno));
    } else {
      gettimeofday(&time1, NULL);
      flowid = ntohl(data->flow_id);
      for (i = 0; i < nflows; i++) {
        if (flows[i].flowid == flowid)
          break;
      }
      if (i == nflows) {
        continue;
      }
      fsp = &(flows[i]);
      /* BUG: the remaining code in the loop should really be atomic, but
       * how do we guaratee that?
       * Anyway, if you stop your sources before hitting CTRL-C this should
       * be OK. */
      seq = ntohl(data->sequence_number);
      fsp->rec++;
      tx_s = ntohl(data->tx_time_seconds);
      tx_us = ntohl(data->tx_time_useconds);
      delay_s = time1.tv_sec - tx_s;
      delay_us = time1.tv_usec - tx_us;
      if (seq <= fsp->seq) {
        fsp->oos++;
        if (seq < fsp->seqmin) {
          /* Should only occur in case of reordering of the first packets */
          fsp->seqmin = seq;
          if (fsp->rec == 1) {
          /* First packet: do the initialization.
           * Here we use a trick to move the initialization conditional out
           * of the normal execution path: we initialized seqmin with
           * ULONG_MAX so that when we receive the first packet it's sequence
           * number is always less than that.  :-)  */
             fsp->oos--; /* The first packet obviously isn't out of sequence */
             fsp->first_rx_sec = time1.tv_sec;
             fsp->first_rx_usec = time1.tv_usec;
             fsp->seq = seq;
             goto update_last;
          }
        }
      } else {
         fsp->seq = seq;
      }
      fsp->ds_sec += delay_s;
      fsp->ds_usec += delay_us;
      jitter_s = delay_s - fsp->last_delay_sec;
      jitter_us = delay_us - fsp->last_delay_usec;
      /* We need the absolute value, so: */
      if (jitter_s < 0) {
        jitter_s = -jitter_s;
        jitter_us = -jitter_us;
      }  /* At this point, jitter_s >= 0 */
      if (jitter_us < 0) {
         if (jitter_s == 0) {
            jitter_us = -jitter_us;
         } else {
            jitter_us += 1000000;
            jitter_s--;
         }
      }  /* Now both jitter components are positive */
      fsp->js_sec += jitter_s;
      fsp->js_usec += jitter_us;
      if (jitter_s > fsp->max_jitter_sec ||
          jitter_s == fsp->max_jitter_sec && jitter_us > fsp->max_jitter_usec) {
        fsp->max_jitter_sec = jitter_s;
        fsp->max_jitter_usec = jitter_us;
      }
update_last:
      fsp->last_tx_sec = tx_s;
      fsp->last_tx_usec = tx_us;
      fsp->last_rx_sec = time1.tv_sec;
      fsp->last_rx_usec = time1.tv_usec;
      fsp->last_delay_sec = delay_s;
      fsp->last_delay_usec = delay_us;
      fsp->s_size += rec_bytes;
    }

    pkt_count++;
    /* Note that we only count packets from the flows we are gathering
     * statistics for: the others don't matter in this case. */
    if((limit != 0) && (pkt_count >= limit)){ break; }
  } /* end of while */

  RUDEBUG1("\ncrude: captured/processed %lu packets\n", pkt_count);
  return 0;
}


/*
 * print_stats() - print the statistics at the end of a runtime statistics
 *                 gathering session
 */
void print_stats(void)
{
  int i;
  struct flow_stat *fsp;
  long long sec, usec;
  double interval;

  printf("\n"
         "Runtime statistics results: \n"
         "--------------------------- \n");
  for (i = 0; i < nflows; i++) {
    fsp = &flows[i];
    printf("\nFlow_ID=%lu \n", fsp->flowid);
    printf("Packets: received=%lu   out-of-seq=%lu   "
           "lost(est)=%lu \n", fsp->rec, fsp->oos,
           fsp->rec > 0 ? (fsp->seq - fsp->seqmin + 1 - fsp->rec) : 0);
    printf("Total bytes received=%llu \n", fsp->s_size);
    if (fsp->rec > 0) {
       printf("Sequence numbers: first=%lu   last=%lu \n",
              fsp->seqmin, fsp->seq);
    }
    if (fsp->rec < 2) {
      printf("Can't calculate statistics: not enough packets received. \n");
      continue;
    }
    sec = fsp->ds_sec / fsp->rec;
    usec = (fsp->ds_usec + 1000000 * (fsp->ds_sec % fsp->rec)) / fsp->rec;
    sec += usec / 1000000;
    usec %= 1000000;

    // printf( "Raw data:       sec = %lld    usec = %lld\n", sec, usec );

    /* Possible with dessynchronized clocks */
    /* sec and usec must have same sign for output */
    if  ( (sec > 0 ) && (usec < 0) ) {
      sec--;
      usec = 1000000 + usec;
    }
    else if ( (sec < 0 ) && (usec > 0) ) {
      sec++;
      usec = -1000000 + usec;
    }

    // printf( "Corrected data: sec = %lld    usec = %lld\n", sec, usec ); 

    /* print average delay as sign and absolute value */
    if ( (sec < 0) || (usec < 0) ) {
      sec  = llabs( sec );
      usec = llabs( usec );
      printf("Delay: average = -%lld.%06llu   ", sec, usec);
    } else {
      printf("Delay: average = %lld.%06llu   ", sec, usec);
    }

    /* Both components of all jitter values are positive, thus the sum of
     * them is also positive */
    sec = fsp->js_sec / (fsp->rec - 1);
    usec = (fsp->js_usec + 1000000 * (fsp->js_sec % (fsp->rec - 1))) /
           (fsp->rec - 1);
    sec += usec / 1000000;
    usec %= 1000000;
    printf("jitter=%llu.%06llu   seconds \n", sec, usec);
    printf("Absolute maximum jitter=%ld.%06ld   seconds \n",
           fsp->max_jitter_sec, fsp->max_jitter_usec);
    sec = (long) fsp->last_rx_sec - (long) fsp->first_rx_sec;
    usec = (long) fsp->last_rx_usec - (long) fsp->first_rx_usec;
    interval = (double) sec + (double) usec / 1000000.0;
    printf("Throughput=%g   Bps  (from first to last packet received) \n",
           (double) fsp->s_size / interval);
  }
  printf("\n");
}


/*
 * rec_to_file() - record packets to file in binary format...
 */
static int rec_to_file(unsigned short port, unsigned long limit)
{
  long               rec_bytes = 0;     /* Bytes read            */
  int                wri_bytes = 0;     /* Bytes written         */
  int                src_len = sizeof(struct sockaddr_in);
  struct sockaddr_in src_addr;
  struct timeval     time1;
  struct crude_struct  other_info;
  char buffer[PMAXSIZE];

  /* Initialize some variables */
  memset(buffer,0,PMAXSIZE);
  other_info.dest_port = htons(port);

  while(1){
    rec_bytes = recvfrom(main_socket, buffer, PMAXSIZE, 0,
			 (struct sockaddr *)&src_addr, &src_len);
    if(rec_bytes <= 0){
      RUDEBUG1("crude: error when receiving packet: %s\n",strerror(errno));
    } else {
      gettimeofday(&time1, NULL);
      pkt_count++;
      other_info.rx_time_seconds  = htonl(time1.tv_sec);
      other_info.rx_time_useconds = htonl(time1.tv_usec);
      other_info.pkt_size         = htonl(rec_bytes);
      other_info.src_port         = src_addr.sin_port;
      other_info.src_addr         = src_addr.sin_addr.s_addr;

      wri_bytes = write(main_file,buffer,(sizeof(struct udp_data)));
      wri_bytes += write(main_file,&other_info,sizeof(struct crude_struct));
      RUDEBUG7("crude: pkt %lu (%ldbytes) status: %s\n",
	       pkt_count, rec_bytes, strerror(errno));
    }

    if((limit != 0) && (pkt_count >= limit)){ break; }
  } /* end of while */

  RUDEBUG1("\ncrude: captured/processed %lu packets\n", pkt_count);
  return 0;
}


/*
 * rec_n_print() - print information of received packets to stdout
 */
static int rec_n_print(unsigned short port, unsigned long limit)
{
  long               rec_bytes = 0;     /* Bytes read            */
  int                src_len   = sizeof(struct sockaddr_in);
  struct sockaddr_in src_addr;
  struct timeval     time1;
  struct udp_data    *udp_ptr;
  struct in_addr     d_add;
  char buffer[PMAXSIZE], str1[16], str2[16];

  /* Initialize some variables */
  memset(buffer,0,PMAXSIZE);
  memset(str1,0,16);
  memset(str2,0,16);

  while(1){
    rec_bytes = recvfrom(main_socket, buffer, PMAXSIZE, 0,
			 (struct sockaddr *)&src_addr, &src_len);
    if(rec_bytes <= 0){
      RUDEBUG1("crude: error when receiving packet: %s\n",strerror(errno));
    } else {
      gettimeofday(&time1, NULL);
      pkt_count++;
      udp_ptr = (struct udp_data*)buffer;
      d_add.s_addr = udp_ptr->dest_addr;
      strncpy(str1,inet_ntoa(src_addr.sin_addr),15);
      strncpy(str2,inet_ntoa(d_add),15);
      printf("ID=%lu SEQ=%lu SRC=%s:%hu DST=%s:%hu "
	     "Tx=%lu.%06lu Rx=%ld.%06ld SIZE=%ld\n",
	     (unsigned long)ntohl(udp_ptr->flow_id),
	     (unsigned long)ntohl(udp_ptr->sequence_number),
	     str1, ntohs(src_addr.sin_port), str2, port,
	     (unsigned long)ntohl(udp_ptr->tx_time_seconds),
	     (unsigned long)ntohl(udp_ptr->tx_time_useconds),
	     time1.tv_sec, time1.tv_usec, rec_bytes);
    }

    if((limit != 0) && (pkt_count >= limit)){ break; }
  } /* end of while */

  RUDEBUG1("\ncrude: captured/processed %lu packets\n", pkt_count);
  return 0;
}
