/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>
#include "common_includes/includes.p4"
const bit<16> TYPE_IPV4 = 0x800;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;



header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}
SRVHEADERS

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}
header ipv6_t{
	bit<4> version;
	bit<8> trafficClass;
	bit<20> flowLabel;
	bit<16> payLoadLen;
	bit<8> nextHdr;
	bit<8> hopLimit;
	bit<128> srcAddr;
	bit<128> dstAddr;
}
// New header type for transfering needed data
header dissaggregation_header_t {
    egressSpec_t port;
    bit<7> padding;
}


struct metadata {
    METADATAFIELDSRV6
    egressSpec_t port; 
}

struct headers {
    SRVHEADERINSTANCES
    ethernet_t   ethernet;
    ipv6_t       ipv6;
    dissaggregation_header_t  dissaggregation_header; // New header for transfering needed data
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    SRVSTATES(packet,hdr)
    state start {
        packet.extract(hdr.ethernet);
        packet.extract(hdr.ipv6);
        transition parse_srh;
    }

    state parse_post_srh{
        transition accept;
    }


}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop();
    }
    counter(1, CounterType.packets) part_1c;
        
    action chg_addr(egressSpec_t port, macAddr_t dstAddr) {
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        standard_metadata.egress_spec = 2;
        meta.port = port;
    }
    
    table ipv6_lpm1 {
        key = {
            hdr.ipv6.dstAddr: lpm;
        }
        actions = {
            chg_addr;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    
    apply {
        part_1c.count(0);
        ipv6_lpm1.apply();
        standard_metadata.egress_spec = standard_metadata.ingress_port;
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply { }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv6);
        SRVEMIT(packet,hdr)
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
