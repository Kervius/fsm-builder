fsm-builder
===========

FSM Generator

Historic code of a FSM builder, used to bootstrap a C++ FSM builder.

Usage:

    fsm-builder.pl test00.fsm > test00.out

The output would contain both C declarations and definitions, for both
switch/case and transition table FSM implementations.

Example FSM
-----------

    fsm test00 {
    	file_code = "xxx.c";
    	file_header = "xxx.h";
    	init_state = a;
    
    	events {
    		evta,
    		evtb,
    		evtc
    	}
    
    	default {
    		evt_error -> . { handle_error };
    		* -> . { bad_transition };
    	}
    
    	state a {
    		evtb -> b;
    		evtc -> c;
    	}
    
    	state b {
    		evtc -> c;
    	}
    
    	state c {
    		evta -> a;
    	}
    }




