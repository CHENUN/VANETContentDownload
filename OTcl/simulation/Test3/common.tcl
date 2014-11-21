# Author: Zou Zhenhua

# ======================================================================
# common parameters
# ======================================================================
set val(chan)		Channel/WirelessChannel			;# channel type
set val(prop)		Propagation/TwoRayGround		;# radio-propagation model
set val(netif)		Phy/WirelessPhy				;# network interface type
set val(mac)		Mac/802_11				;# MAC type
set val(ifq)		Queue/DropTail/PriQueue			;# interface queue type
set val(ll)		LL					;# link layer type
set val(ant)		Antenna/OmniAntenna			;# antenna model
set val(ifqlen)		50					;# max packet in ifq
set val(AP)		1					;# number of Access Point
set val(rp)		AODV					;# routing protocol
set val(cp)		Trace					;# the mobility file generated by VanetMobiSim
set val(start)          1.0                                     ;# simulation start time
set val(stop)		380					;# simulation stop time
set val(nn)		[expr $val(AP)+$val(MN)]		;# number of mobilenodes & Access Point
set val(FILE_SIZE)      300000                                  ;# file size
set val(bw)		11Mb					;# bandwidth for vehicles and AP

# ======================================================================
# Main Program
# ======================================================================

# Initialize Global Variables
set ns_     [new Simulator]

$ns_ use-newtrace
set tracefd [open /dev/null w]
$ns_ trace-all $tracefd

# nam trace is only used for the estimation of the simulation stop time
set namtrace [open out.nam w]
$ns_ namtrace-all-wireless $namtrace 1000 1000

# Set Up Topography Object
set topo       [new Topography]
$topo load_flatgrid 1000 1000

# Create God
create-god $val(nn)

# Configure default data rate for 802.11
Mac/802_11 set dataRate_ $val(bw)
# Disable RTS/CTS
Mac/802_11 set RTSThreshold_ 3000

# the transmission range is 150m
Phy/WirelessPhy set RXThresh_ 2.81838e-09

# Configure Node
$ns_ node-config -adhocRouting $val(rp) \
		 -llType $val(ll) \
		 -macType $val(mac) \
		 -ifqType $val(ifq) \
		 -ifqLen $val(ifqlen) \
		 -antType $val(ant) \
		 -propType $val(prop) \
		 -phyType $val(netif) \
		 -topoInstance $topo \
		 -agentTrace OFF \
		 -routerTrace OFF \
		 -macTrace OFF \
		 -movementTrace OFF \
		 -channel [new $val(chan)]
			 
# Define Vehicles & Access Point nodes
for {set i 0} {$i < $val(nn) } {incr i} {
	set node_($i) [$ns_ node]
	$node_($i) random-motion 0
}

# Define Node Movement Model
puts "Loading mobility pattern..."
source $val(cp)

for {set i 0} {$i < $val(nn)} {incr i} {
    # 10 defines the node size in nam, must adjust it according to your scenario  
    # The function must be called after mobility model is defined
    $ns_ initial_node_pos $node_($i) 10
}

# ======================================================================
# global parameter input to the VCD application
# ======================================================================
# be careful to input the correct name, otherwise these value could be set to default value, which is specified in the source code.
InputParameter gps_interval_ 1
InputParameter adver_timeout_ 0.15
InputParameter traffic_timeout_ 0.1
InputParameter cts_timeout_ 0.2
InputParameter transfer_ack_timeout_ 0.3
InputParameter cts_tx_timeout_ 0.09
InputParameter packet_size_ 512 
InputParameter file_size_ $val(FILE_SIZE)
InputParameter ap_num_ $val(AP)
InputParameter vehicle_num_ $val(MN)
# the radio range is set according to the rx threshold value
InputParameter radio_range_ 150

# ======================================================================
# group manager protocol 
# ======================================================================
set gm [new GroupManager]
$ns_ at $val(start) "$gm start"

# ======================================================================
# Traffic Type & Simluation Time
# ======================================================================

# setting for the Access Point
for { set i $val(MN) } { $i < $val(nn) } { incr i } {
        set MessagePassing_($i) [new Agent/MessagePassing]
        $ns_ attach-agent $node_($i) $MessagePassing_($i)

        set VCD_($i) [new Application/VCDServer]
        $VCD_($i) attach-agent $MessagePassing_($i)
        $VCD_($i) set id_ $i

        $ns_ at $val(start) "$VCD_($i) start"
        $ns_ at $val(stop) "$VCD_($i) stop"
}

# setting for vehicle nodes
for { set i 0 } { $i < $val(MN) } { incr i } {
        set MessagePassing_($i) [new Agent/MessagePassing]
        $ns_ attach-agent $node_($i) $MessagePassing_($i)

        set VCD_($i) [new Application/VCDClient]
        $VCD_($i) attach-agent $MessagePassing_($i)
        $VCD_($i) set id_ $i

        $ns_ at $val(start) "$VCD_($i) start"
        $ns_ at $val(stop) "$VCD_($i) stop"
}

# ======================================================================
# global simluation time
# ======================================================================
$ns_ at $val(stop).9999 "puts \"NS EXITING...\" ; $ns_ halt"
$ns_ at $val(stop) "stop"

# ======================================================================
# exit function
# ======================================================================
proc stop {} {
    global ns_ tracefd
    global namtrace
    $ns_ flush-trace
    close $tracefd
    close $namtrace
}

# ======================================================================
# start
# ======================================================================
puts "Starting Simulation..."
$ns_ run
