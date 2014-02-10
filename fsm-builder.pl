#!/usr/bin/env perl

use strict;
use warnings;
#use Data::Dumper;

my %fsm;

use constant {
	nl  => "\n",
	tab => "\t"
};

=head
fsm xxx {
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
		evtb -> b {};
		evtc -> c;
	}

	state b {
		evtc -> c;
	}

	state c {
		evta -> a;
	}
}
=cut

my $id_re = qr/[_a-zA-Z][_a-zA-Z0-9]*/;

sub STATE_INIT		{ 1 };
sub STATE_FSM_NAME	{ 2 };
sub STATE_FSM_OPEN_BRACKET	{ 3 };
sub STATE_FSM_CLOSE_BRACKET	{ 4 };

sub STATE_FSM_BODY	{ 5 };

sub STATE_FSM_FCODE1	{ 6 };
sub STATE_FSM_FCODE2	{ 7 };
sub STATE_FSM_FCODE3	{ 8 };
sub STATE_FSM_FHEADER1	{ 9 };
sub STATE_FSM_FHEADER2	{ 10 };
sub STATE_FSM_FHEADER3	{ 11 };
sub STATE_FSM_INIT_STATE1	{ 12 };
sub STATE_FSM_INIT_STATE2	{ 13 };
sub STATE_FSM_INIT_STATE3	{ 14 };
sub STATE_FSM_EVENTS1	{ 15 };
sub STATE_FSM_EVENTS2	{ 16 };
sub STATE_FSM_EVENTS3	{ 17 };

sub STATE_FSM_DEFL		{ 30 };
sub STATE_FSM_DEFL_EVTN		{ 31 };
sub STATE_FSM_DEFL_TO		{ 32 };
sub STATE_FSM_DEFL_ST		{ 33 };
sub STATE_FSM_DEFL_FUNC1	{ 34 };
sub STATE_FSM_DEFL_FUNC2	{ 35 };
sub STATE_FSM_DEFL_FUNC3	{ 36 };
sub STATE_FSM_DEFL_SC		{ 37 };
sub STATE_FSM_DEFL_TR		{ 38 };


sub STATE_FSM_STATE		{ 100 };
sub STATE_FSM_STATE_OBR		{ 101 };
sub STATE_FSM_STATE_EVTN	{ 102 };
sub STATE_FSM_STATE_TO		{ 103 };
sub STATE_FSM_STATE_ST		{ 104 };
sub STATE_FSM_STATE_FUNC1	{ 105 };
sub STATE_FSM_STATE_FUNC2	{ 106 };
sub STATE_FSM_STATE_FUNC3	{ 107 };
sub STATE_FSM_STATE_SC		{ 108 };
sub STATE_FSM_STATE_TR		{ 109 };


my $state = &STATE_INIT;
my $l;
my $t;

my ($fsm_name, $state_name, $tr_event, $tr_state, $tr_code);

my ($obr, $cbr) = ('{', '}');

# ------------------------------------------------------------- parsing ------

while ($l = <>) {
	chomp($l);
	next if $l =~ /^\s*#/;	# comments
	$l =~ s/^\s+//;
	$l =~ s/^\s*#.*//;
	while (length $l) {
		if ($state == &STATE_INIT)
		{
			$t = &pop_token( \$l, 'fsm' );
			$state = &STATE_FSM_NAME;
		}
		elsif ($state == &STATE_FSM_NAME)
		{
			$fsm_name = &pop_token( \$l, $id_re, 'fsm name' );
			die "fsm '$fsm_name' already exists" if exists $fsm{$fsm_name};
			$fsm{$fsm_name} = { events => [], trans => {} };
			$fsm{$fsm_name}{fsm_name} = $fsm_name;
			$state = &STATE_FSM_OPEN_BRACKET;
			print "/* parsing fsm $fsm_name... */\n";
		}
		elsif ($state == &STATE_FSM_OPEN_BRACKET)
		{
			$t = &pop_token( \$l, $obr, $obr );
			$state = &STATE_FSM_BODY;
		}
		elsif ($state == &STATE_FSM_BODY)
		{
			$t = &pop_token( \$l, qr(file_code|file_header|init_state|events|state|default|$cbr), 'fsm part def' );
			if ($t eq 'file_code') {
				$state = &STATE_FSM_FCODE1;
			} elsif ($t eq 'file_header') {
				$state = &STATE_FSM_FHEADER1;
			} elsif ($t eq 'init_state') {
				$state = &STATE_FSM_INIT_STATE1;
			} elsif ($t eq 'events') {
				$state = &STATE_FSM_EVENTS1;
			} elsif ($t eq 'state') {
				$state = &STATE_FSM_STATE;
			} elsif ($t eq 'default') {
				$state = &STATE_FSM_DEFL;
			} elsif ($t eq $cbr) {
				print "/* parsing fsm $fsm_name done. */\n";
			} else {
				die;
			}
		}
		elsif ($state == &STATE_FSM_FCODE1) 
		{
			$t = &pop_token( \$l, qr/\Q=\E/);
			$state = &STATE_FSM_FCODE2;
		}
		elsif ($state == &STATE_FSM_FCODE2)
		{
			$t = &pop_token( \$l, qr{"[a-zA-Z0-9_/\.]+"}, 'file name in double quotes' );
			$fsm{$fsm_name}{file_code} = $t;
			warn "$fsm_name: file_code = $t\n";
			$state = &STATE_FSM_FCODE3
		}
		elsif ($state == &STATE_FSM_FCODE3)
		{
			$t = &pop_token( \$l, ';' );
			$state = &STATE_FSM_BODY;
		}
		elsif ($state == &STATE_FSM_FHEADER1)
		{
			$t = &pop_token( \$l, qr/=/);
			$state = &STATE_FSM_FHEADER2;
		}
		elsif ($state == &STATE_FSM_FHEADER2)
		{
			$t = &pop_token( \$l, qr{"[a-zA-Z0-9_/\.]+"}, 'file name in double quotes' );
			$fsm{$fsm_name}{file_header} = $t;
			warn "$fsm_name: file_header = $t\n";
			$state = &STATE_FSM_FHEADER3
		}
		elsif ($state == &STATE_FSM_FHEADER3)
		{
			$t = &pop_token( \$l, ';' );
			$state = &STATE_FSM_BODY;
		}
		elsif ($state == &STATE_FSM_INIT_STATE1)
		{
			$t = &pop_token( \$l, qr/=/);
			$state = &STATE_FSM_INIT_STATE2;
		}
		elsif ($state == &STATE_FSM_INIT_STATE2)
		{
			$t = &pop_token( \$l, $id_re, 'init state name' );
			$fsm{$fsm_name}{init_state} = $t;
			warn "$fsm_name: init_state = $t\n";
			$state = &STATE_FSM_INIT_STATE3
		}
		elsif ($state == &STATE_FSM_INIT_STATE3)
		{
			$t = &pop_token( \$l, ';' );
			$state = &STATE_FSM_BODY;
		}
		elsif ($state == &STATE_FSM_EVENTS1)
		{
			$t = &pop_token( \$l, $obr );
			$state = &STATE_FSM_EVENTS2
		}
		elsif ($state == &STATE_FSM_EVENTS2)
		{
			$t = &pop_token( \$l, $id_re, 'event name' );
			push @{$fsm{$fsm_name}{events}}, $t;
			$state = &STATE_FSM_EVENTS3;
		}
		elsif ($state == &STATE_FSM_EVENTS3)
		{
			$t = &pop_token( \$l, qr/,|$cbr/ );
			if ($t eq ',') {
				$state = &STATE_FSM_EVENTS2;
			} elsif ($t eq $cbr) {
				$state = &STATE_FSM_BODY;
			} else {
				die;
			}
		}
		elsif ($state == &STATE_FSM_DEFL)
		{
			$state_name = '*';
			$t = &pop_token( \$l, $obr );
			$state = &STATE_FSM_DEFL_EVTN;
		}
		elsif ($state == &STATE_FSM_DEFL_EVTN)
		{
			$t = &pop_token( \$l, qr/$id_re|\*|$cbr/, 'event name' );
			if ($t eq $cbr) {
				$state = &STATE_FSM_BODY;
			} else {
				$tr_event = $t;
				$state = &STATE_FSM_DEFL_TO;
			}
		}
		elsif ($state == &STATE_FSM_DEFL_TO)
		{
			$t = &pop_token( \$l, '->' );
			$state = &STATE_FSM_DEFL_ST;
		}
		elsif ($state == &STATE_FSM_DEFL_ST)
		{
			$t = &pop_token( \$l, qr/$id_re|\./, 'state name' );
			$tr_state = $t;
			$state = &STATE_FSM_DEFL_FUNC1;
		}
		elsif ($state == &STATE_FSM_DEFL_FUNC1)
		{
			$t = &pop_token( \$l, qr/$obr|;/ );
			if ($t eq ';') {
				$tr_code = '';
				$state = &STATE_FSM_DEFL_TR;
			} else {
				$state = &STATE_FSM_DEFL_FUNC2;
			}
		}
		elsif ($state == &STATE_FSM_DEFL_FUNC2)
		{
			$t = &pop_token( \$l, $id_re, 'function name' );
			$tr_code = $t;
			$state = &STATE_FSM_DEFL_FUNC3;
		}
		elsif ($state == &STATE_FSM_DEFL_FUNC3)
		{
			$t = &pop_token( \$l, $cbr );
			$state = &STATE_FSM_DEFL_SC;
		}
		elsif ($state == &STATE_FSM_DEFL_SC)
		{
			$t = &pop_token( \$l, ';' );
			$state = &STATE_FSM_DEFL_TR;
		}
		elsif ($state == &STATE_FSM_DEFL_TR)
		{
			&add_trans( $fsm{$fsm_name}, $state_name, 
					$tr_event, $tr_state, $tr_code );

			if ($t eq $cbr) {
				$state = &STATE_FSM_BODY;
			} else {
				$state = &STATE_FSM_DEFL_EVTN;
			}
		}
		elsif ($state == &STATE_FSM_STATE)
		{
			$t = &pop_token( \$l, $id_re, 'state name' );
			$state_name = $t;
			$state = &STATE_FSM_STATE_OBR;
		}
		elsif ($state == &STATE_FSM_STATE_OBR)
		{
			$t = &pop_token( \$l, $obr );
			$state = &STATE_FSM_STATE_EVTN;
		}
		elsif ($state == &STATE_FSM_STATE_EVTN)
		{
			$t = &pop_token( \$l, qr/$id_re|\*|$cbr/, 'event name' );
			if ($t eq $cbr) {
				$state = &STATE_FSM_BODY;
			} else {
				$tr_event = $t;
				$state = &STATE_FSM_STATE_TO;
			}
		}
		elsif ($state == &STATE_FSM_STATE_TO)
		{
			$t = &pop_token( \$l, '->' );
			$state = &STATE_FSM_STATE_ST;
		}
		elsif ($state == &STATE_FSM_STATE_ST)
		{
			$t = &pop_token( \$l, qr/$id_re|\./, 'state name' );
			$tr_state = $t;
			$state = &STATE_FSM_STATE_FUNC1;
		}
		elsif ($state == &STATE_FSM_STATE_FUNC1)
		{
			$t = &pop_token( \$l, qr/$obr|;/ );
			if ($t eq ';') {
				$tr_code = '';
				$state = &STATE_FSM_STATE_TR;
			} else {
				$state = &STATE_FSM_STATE_FUNC2;
			}
		}
		elsif ($state == &STATE_FSM_STATE_FUNC2)
		{
			$t = &pop_token( \$l, $id_re, 'function_name' );
			$tr_code = $t;
			$state = &STATE_FSM_STATE_FUNC3;
		}
		elsif ($state == &STATE_FSM_STATE_FUNC3)
		{
			$t = &pop_token( \$l, $cbr );
			$state  = &STATE_FSM_STATE_SC;
		}
		elsif ($state == &STATE_FSM_STATE_SC)
		{
			$t = &pop_token( \$l, ';' );
			$state = &STATE_FSM_STATE_TR;
		}
		elsif ($state == &STATE_FSM_STATE_TR)
		{
			&add_trans( $fsm{$fsm_name}, $state_name, 
					$tr_event, $tr_state, $tr_code );

			if ($t eq $cbr) {
				$state = &STATE_FSM_BODY;
			} else {
				$state = &STATE_FSM_STATE_EVTN;
			}
		}
		else
		{
			die "unhandled state $state";
		}
		$l =~ s/^\s+//;
		$l =~ s/^\s*#.*//;
	}
}

#print Dumper( {%fsm} );

# ----------------------------------------------------- code generation ------

print "/* found fsm: ".join(', ', keys %fsm)." */\n";
if (0) {
for $fsm_name (keys %fsm) {
	my (@states) = &find_states($fsm{$fsm_name});
	my (@events) = &find_events($fsm{$fsm_name});
	my (@funcs) = &find_funcs($fsm{$fsm_name});

	print "\n";
	print "/* $fsm_name states: ".join(', ', @states)." */\n";
	print "/* $fsm_name events: ".join(', ', @events)." */\n";

	# header part...
	print "\n";
	print "typedef enum ${fsm_name}_event {\n";
	print "\t".join(",\n\t", @events)."\n";
	print "} ${fsm_name}_event_t; /* enum ${fsm_name}_event */\n";
	print "\n";
	print "typedef enum ${fsm_name}_state {\n";
	print "\t".join(",\n\t", @states)."\n";
	print "} ${fsm_name}_state_t; /* enum ${fsm_name}_state */\n";
	print "\n";
	print "enum { ${fsm_name}_event_no = ".@events." };\n";
	print "enum { ${fsm_name}_state_no = ".@states." };\n";
	print "\n";
	print "struct ${fsm_name}_fsm;\n";
	print "typedef void (* ${fsm_name}_func_t) ( struct ${fsm_name}_fsm *fsm, enum ${fsm_name}_event evt );\n";
	print "\n";
	print "struct ${fsm_name}_fsm_trans {\n";
	print "\t"."${fsm_name}_state_t new_state;\n";
	print "\t"."${fsm_name}_func_t action;\n";
	print "}; /* struct ${fsm_name}_trans */\n";
	print "\n";
	print "typedef struct ${fsm_name}_fsm_trans ${fsm_name}_fsm_trans_table_t[${fsm_name}_state_no][${fsm_name}_event_no];\n";
	print "\n";
	print "struct ${fsm_name}_fsm {\n";
	print "\t"."enum ${fsm_name}_state state;\n";
	print "\t"."enum ${fsm_name}_event last_event;\n";
	print "\t"."enum ${fsm_name}_state prev_state;\n";
	print "\t"."${fsm_name}_fsm_trans_table_t *trans_table;\n";
	print "}; /* struct ${fsm_name}_fsm */\n";
	print "\n";
	print "/* fsm $fsm_name func declarations */\n";
	print "void $_(struct ${fsm_name}_fsm *fsm, enum ${fsm_name}_event evt);\n" for (@funcs);
	print "/* fsm $fsm_name func declarations end */\n";
	print "\n";

	# code part...
	print "\n";
	print "#if defined(${fsm_name}_use_tt) && ${fsm_name}_use_tt == 1\n";
	print "/* fsm $fsm_name trans table */\n";
	print "struct ${fsm_name}_fsm_trans ${fsm_name}_fsm_trans_table[${fsm_name}_state_no][${fsm_name}_event_no] = {\n";
	for my $st (@states) {
		print "\t/* fsm $fsm_name trans table : state $st */\n";
		print "\t{\n";
		for my $ev (@events) {
			my $tr = &find_trans( $fsm{$fsm_name}, $st, $ev );
			die "trans from $st/$ev isn't defined" unless defined $tr;
			print "\t\t{ ".$$tr{new_state}.", ".($$tr{code} ? $$tr{code} : "0")." },\t/* $ev */\n";
		}
		print "\t},\n";
	#	print "\t/* fsm $fsm_name trans table : state $st end */\n";
	}
	print "}; /* end of ${fsm_name}_trans_table[${fsm_name}_state_no][${fsm_name}_event_no] */\n";
	print "\n";
	print "void ${fsm_name}_fsm_trigger ( struct ${fsm_name}_fsm *fsm, enum ${fsm_name}_event evt )\n";
	print "{\n";
	print "\tstruct ${fsm_name}_fsm_trans *trans;\n";
	print "\tfsm->last_event = evt;\n";
	print "\ttrans = fsm->trans_table[fsm->state][evt];\n";
	print "\tif (fsm->state != trans->new_state) { fsm->prev_state = fsm->state; }\n";
	print "\tfsm->state = trans->new_state;\n";
	print "\tif (trans->action) trans->action(fsm, evt);\n";
	print "}\n";
	print "\n";
	print "/* fsm $fsm_name trans table end */\n";
	print "\n";
	print "\n";
	print "#else /* define(${fsm_name}_use_tt) && ${fsm_name}_use_tt == 1 */\n";
	print "\n";
	print "/* fsm $fsm_name switch/case implementation */\n";
	print "void ${fsm_name}_fsm_trigger ( struct ${fsm_name}_fsm *fsm, enum ${fsm_name}_event evt )\n";
	print "{\n";
	print "\tfsm->last_event = evt;\n";
	print "\tswitch(fsm->state) {\n";
	for my $st (@states) {
		print "\tcase $st:\n";
		print "\t\tswitch(evt) {\n";
		my %hh;
		for my $ev (@events) {
			my $tr = &find_trans( $fsm{$fsm_name}, $st, $ev );
			die "trans from $st/$ev isn't defined\n" unless defined $tr;
			my $id = $$tr{new_state}.";".$$tr{code};
			if (exists $hh{$id}) {
				push @{$hh{$id}}, $ev;
			} else {
				$hh{$id} = [ $ev ];
			}
		}
		my @kk = sort { @{$hh{$a}} <=> @{$hh{$b}} } keys %hh;
		for my $x (@kk) {
			my ($new_state, $code) = split(/;/, $x, 2);
			if ($x eq $kk[$#kk]) {
				print "\t\tdefault:\n"
			} else {
				for (@{$hh{$x}}) {
					print "\t\tcase $_:\n";
				}
			}
			if ($st ne $new_state) {
				print "\t\t\t"."fsm->prev_state = $st;\n";
				print "\t\t\t"."fsm->state = $new_state;\n";
			}
			print "\t\t\t"."$code(fsm, evt);\n" if $code;
			print "\t\t\t"."break;\n";
		}
		print "\t\t}\n";
		print "\t\tbreak;\n";
	}
	print "\t}\n";
	print "}\n";
	print "/* fsm $fsm_name switch/case implementation end */\n";
	print "\n";
	print "#endif /* define(${fsm_name}_use_tt) && ${fsm_name}_use_tt == 1 */\n";
	print "\n";
}
}


# ------------------------------------------------------------- utility ------

sub find_trans {
	my ($fsm, $st, $ev) = (@_);

	die if $st eq '*' or $st eq '.' or $ev eq '*';

	# 1. trans for the $st/$ev
	# 2. trans for the $st/*
	# 3. trans for the */$ev
	# 4. trans for the */*

	my %h = (old_state => $st, event => $ev);

	for my $xst ($st, '*') {
		if (exists $$fsm{trans}{$st}) {
			# 1, 3
			for my $tr (@{$$fsm{trans}{$xst}}) {
				next if $$tr{event} ne $ev;
				$h{new_state} = $$tr{new_state};
				$h{new_state} = $h{old_state} if ($h{new_state} eq '.');
			#	$h{code} = $$tr{code};
				$h{code} = defined $$tr{code} && length $$tr{code} ? $$tr{code} : '';
				return \%h;
			}

			# 2, 4
			for my $tr (@{$$fsm{trans}{$xst}}) {
				if ($$tr{event} eq '*') {
					$h{new_state} = $$tr{new_state};
					$h{new_state} = $h{old_state} if ($h{new_state} eq '.');
					$h{code} = defined $$tr{code} && length $$tr{code} ? $$tr{code} : '';
					return \%h;
				}
			}
		}
	}
	undef;
}

sub find_states {
	my ($fsm) = (@_);
	return grep { !/^(\*|\.)$/ } sort keys %{$$fsm{trans}};
}

sub find_events {
	my ($fsm) = (@_);
	my (@expl_events) = @{$$fsm{events}};
	my (@impl_events);
	for my $st (keys %{$$fsm{trans}}) {
		for my $tr (@{$$fsm{trans}{$st}}) {
			push @impl_events, $$tr{event};
		}
	}
	my %h = map { $_ => 1 } (@expl_events, @impl_events);
	delete @h{@expl_events};
	return (@expl_events, grep { !/^\*$/ } sort keys %h);
}

sub find_funcs {
	my ($fsm) = (@_);
	my @funcs;
	for my $st (keys %{$$fsm{trans}}) {
		for my $tr (@{$$fsm{trans}{$st}}) {
			push @funcs, $$tr{code} if defined $$tr{code} and length $$tr{code};
		}
	}
	my %h = map { $_ => 1 } @funcs;
	return sort keys %h;
}

sub add_trans {
	my ($fsm, $old_state, $event, $new_state, $code) = @_;
	$$fsm{trans}{$old_state} = [] unless exists $$fsm{trans}{$old_state};

	push @{$$fsm{trans}{$old_state}}, { 
		event => $event,
		new_state => $new_state,
		code => $code
	};
#	warn $$fsm{fsm_name}.": transition: $old_state + $event -> $new_state { $code }\n";
}

sub pop_token {
	my ($l, $re, $pre) = (@_);
	$pre = $re unless defined $pre;

	die "empty input" if $$l =~ /^\s*$/;

	# uhm... this is a hack.
	if (1 == length $re) {
#		warn "$re";
		if ($re eq substr( $$l, 0, 1 )) {
			$$l =~ s/.//;
			return $re;
		} else {
			die "expected '$pre' token ($state). line $.: '$$l' qr='$re'\n";
		}
	}

	if ($$l =~ /^($re)/) {
		my $t = $1;
		die unless length $t;
		$$l =~ s/^($re)//;
		return $t;
	} else {
		die "expected '$pre' token ($state). line $.: '$$l' qr='$re'\n";
	}
}


=head1
building blocks:

= header

   fsm-builder:$fsm_name:events:

   fsm-builder:$fsm_name:states:

   fsm-builder:$fsm_name:types:

   fsm-builder:$fsm_name:user-func-decl:

   fsm-builder:$fsm_name:func-decl:

   fsm-builder:$fsm_name:data-decl:

= source

   fsm-builder:$fsm_name:timestamp-signature:
   fsm-builder:$fsm_name:header:
   fsm-builder:$fsm_name:fsm-dump:

tt = transition table
   fsm-builder:$fsm_name:tt-table-def:
   fsm-builder:$fsm_name:tt-func-def-header:
   fsm-builder:$fsm_name:tt-func-def-trans:
   fsm-builder:$fsm_name:tt-func-def-action:
   fsm-builder:$fsm_name:tt-func-def-footer:

sc1 = single switch/case function
   fsm-builder:$fsm_name:sc1-func-def-header:
   fsm-builder:$fsm_name:sc1-func-def-sc:
   fsm-builder:$fsm_name:sc1-func-def-footer:

ssc = switch/case function per state + one for the states
   fsm-builder:$fsm_name:ssc-func-def-header:
   fsm-builder:$fsm_name:ssc-func-def-sc:
   fsm-builder:$fsm_name:ssc-func-def-footer:
   fsm-builder:$fsm_name:ssc-func-st-$st_name-def-header:
   fsm-builder:$fsm_name:ssc-func-st-$st_name-def-sc:
   fsm-builder:$fsm_name:ssc-func-st-$st_name-def-footer:


=cut

{
package lang::c;
use constant tab => "\t";
sub bb_get_states
{
	my $self = shift;
	my ($fsm) = @_;
	my @states = main::find_states( $fsm );
	my $fsm_name = $fsm->{fsm_name};
	my @ret;
	push @ret, "typedef enum ${fsm_name}_state {";
	push @ret, tab.$_."," for @states[0..$#states];
	push @ret, tab.$states[-1];
	push @ret, "} ${fsm_name}_state_t; /* enum ${fsm_name}_state */";
	push @ret, "enum { ${fsm_name}_state_no = ".@states." };";
	return @ret;
}

sub bb_get_events
{
	my $self = shift;
	my ($fsm) = @_;
	my @events = main::find_events( $fsm );
	my $fsm_name = $fsm->{fsm_name};
	my @ret;
	push @ret, "typedef enum ${fsm_name}_event {";
	push @ret, tab.$_."," for @events[0..$#events];
	push @ret, tab.$events[-1];
	push @ret, "} ${fsm_name}_event_t; /* enum ${fsm_name}_event */";
	push @ret, "enum { ${fsm_name}_event_no = ".@events." };";
	return @ret;
}

sub bb_get_user_funcs_decl
{
	my $self = shift;
	my ($fsm) = @_;
	my @funcs = main::find_funcs($fsm{$fsm_name});
	my $fsm_name = $fsm->{fsm_name};
	my @ret;
	push @ret, "void $_(struct ${fsm_name}_fsm *fsm, enum ${fsm_name}_event evt);" for @funcs;
	return @ret;
}

sub bb_get_funcs_decl
{
	my $self = shift;
	my ($fsm) = @_;
	my $fsm_name = $fsm->{fsm_name};
	my @ret;

	push @ret, "void ${fsm_name}_fsm_trigger ( struct ${fsm_name}_fsm *fsm, enum ${fsm_name}_event evt )";

	return @ret;
}

sub bb_get_types
{
	my $self = shift;
	my ($fsm) = @_;
	my $fsm_name = $fsm->{fsm_name};
	my @ret;

	push @ret, "struct ${fsm_name}_fsm;";
	push @ret, "typedef void (* ${fsm_name}_func_t) ( struct ${fsm_name}_fsm *fsm, enum ${fsm_name}_event evt );";
	push @ret, "";
	push @ret, "struct ${fsm_name}_fsm_trans {";
	push @ret, tab."${fsm_name}_state_t new_state;";
	push @ret, tab."${fsm_name}_func_t action;";
	push @ret, "}; /* struct ${fsm_name}_trans */";
	push @ret, "";
	push @ret, "typedef struct ${fsm_name}_fsm_trans ${fsm_name}_fsm_trans_table_t[${fsm_name}_state_no][${fsm_name}_event_no];";
	push @ret, "";
	push @ret, "struct ${fsm_name}_fsm {";
	push @ret, tab."enum ${fsm_name}_state state;";
	push @ret, tab."enum ${fsm_name}_event last_event;";
	push @ret, tab."enum ${fsm_name}_state prev_state;";
	push @ret, tab."${fsm_name}_fsm_trans_table_t *trans_table;";
	push @ret, "}; /* struct ${fsm_name}_fsm */";

	return @ret;
}

sub bb_get_data_decl
{
	return '';
}

sub bb_get_timestamp_signature
{
	my $self = shift;
	my ($fsm) = @_;
	my $fsm_name = $fsm->{fsm_name};
	return "/* $fsm_name : generated on ".localtime." */";
}

sub bb_get_header
{
	return '';
}

sub bb_get_fsm_dump
{
	return '';
}

sub bb_get_tt_table_def
{
	my $self = shift;
	my ($fsm) = @_;
	my $fsm_name = $fsm->{fsm_name};
	my @ret;
	my @states = main::find_states( $fsm );
	my @events = main::find_events( $fsm );

	push @ret, "/* fsm $fsm_name trans table */";
	push @ret, "struct ${fsm_name}_fsm_trans ${fsm_name}_fsm_trans_table".
				"[${fsm_name}_state_no][${fsm_name}_event_no] = {";
	for my $st (@states) {
		push @ret, tab."/* fsm $fsm_name trans table : state $st */";
		push @ret, tab."{";
		for my $ev (@events) {
			my $tr = main::find_trans( $fsm{$fsm_name}, $st, $ev );
			die "trans from $st/$ev isn't defined" unless defined $tr;
			push @ret, tab.tab."{ ".$$tr{new_state}.", ".($$tr{code} ? $$tr{code} : "0")." },\t/* $ev */";
		}
		push @ret, tab."},";
	#	print "\t/* fsm $fsm_name trans table : state $st end */\n";
	}
	push @ret, "}; /* end of ${fsm_name}_trans_table[][] */";

	return @ret;
	
}


sub bb_get_tt_func_def_header
{
	my $self = shift;
	my ($fsm) = @_;
	my $fsm_name = $fsm->{fsm_name};
	my @ret;
	push @ret, "void ${fsm_name}_fsm_trigger ( struct ${fsm_name}_fsm *fsm, enum ${fsm_name}_event evt )";
	push @ret, "{";
	push @ret, tab."struct ${fsm_name}_fsm_trans *trans;";
	return @ret;
}

sub bb_get_tt_func_def_trans
{
	#my $self = shift;
	#my ($fsm) = @_;
	#my $fsm_name = $fsm->{fsm_name};
	my @ret;
	push @ret, tab."fsm->last_event = evt;";
	push @ret, tab."trans = fsm->trans_table[fsm->state][evt];";
	push @ret, tab."if (fsm->state != trans->new_state) { fsm->prev_state = fsm->state; }";
	push @ret, tab."fsm->state = trans->new_state;";
	return @ret;
}

sub bb_get_tt_func_def_action
{
	#my $self = shift;
	#my ($fsm) = @_;
	#my $fsm_name = $fsm->{fsm_name};
	#my @ret;
	return tab."if (trans->action) trans->action(fsm, evt);";
}

sub bb_get_tt_func_def_footer
{
	#my $self = shift;
	#my ($fsm) = @_;
	#my $fsm_name = $fsm->{fsm_name};
	#my @ret;
	return "}";
}


sub bb
{
	my $self = shift;
	my ($bb_name) = shift;
	my %bb_map = (
		'states'		=>	\&bb_get_states,
		'events'		=>	\&bb_get_events,
		'user-funcs-decl'	=>	\&bb_get_user_funcs_decl,
		'funcs_decl'		=>	\&bb_get_funcs_decl,
		'types'			=>	\&bb_get_types,
		'data_decl'		=>	\&bb_get_data_decl,
		'timestamp-signature'	=>	\&bb_get_timestamp_signature,
		'header'		=>	\&bb_get_header,
		'fsm_dump'		=>	\&bb_get_fsm_dump,
		'tt-table-def'		=>	\&bb_get_tt_table_def,
		'tt-func-def-header'	=>	\&bb_get_tt_func_def_header,
		'tt-func-def-trans'	=>	\&bb_get_tt_func_def_trans,
		'tt-func-def-action'	=>	\&bb_get_tt_func_def_action,
		'tt-func-def-footer'	=>	\&bb_get_tt_func_def_footer,
	);

	return $bb_map{$bb_name}->( $self, @_ ) if exists $bb_map{$bb_name};
	'';
}

sub bb_default
{
	my ($self, $ft) = @_;
	if ($ft eq 'h') {
		return qw/timestamp-signature states events user-funcs-decl funcs_decl types data_decl/;
	}
	if ($ft eq 's') {
		return qw/timestamp-signature header fsm-dump tt-table-def 
			tt-func-def-header tt-func-def-trans tt-func-def-action tt-func-def-footer/;
	}
}

sub bb_prefix
{
	my $self = shift;
	my ($fsm_name) = @_;
	'/* fsm-builder:'.$fsm_name.':';
}

sub bb_suffix
{
	' */';
}

sub guess_file_type
{
	my ($self, $fn) = @_;
	if ($fn =~ /\.h$/) {
		return 'h';
	}
	if ($fn =~ /\.c$/) {
		return 's';
	}
	return '';
}

sub new
{
	my ($class) = @_;
	return bless {}, $class;
}

} # package


sub read_source
{
	my ($fsm_name, $lang, @files) = @_;
	my %src;

	my $pref = $lang->bb_prefix( $fsm_name );
	my $suff = $lang->bb_suffix( $fsm_name );

	for my $fn (@files) {
		open my $f, '<', $fn or do {
			warn "oops: $fn: $!";
			next;
		};
		my @lines;
		my $curr_bb;
		while (my $l = <$f>) {
			chomp $l;
			if ($l =~ m!^\Q$pref\E(.*):(begin|end|empty)\Q$suff\E$!) {
				my ($bb, $mark) = ($1, $2);
				if ($mark eq 'empty') {
					die "un-ended fsm marker" if $curr_bb;
					push @lines, \"$bb";
				}
				if ($mark eq 'end') {
					die "end without begin" unless $curr_bb;
					die "wrong end" unless $bb eq $curr_bb;
					$curr_bb = '';
					push @lines, \"$bb";
				}
				elsif ($mark eq 'begin') {
					die "un-ended fsm marker" if $curr_bb;
					$curr_bb = $bb;
				}
				else {
					die;
				}
			}
			elsif ($curr_bb) {
				# ignore generated line, part of building block
			} else {
				push @lines, $l;
			}
		}
		die "un-ended fsm marker" if $curr_bb;
		$src{$fn} = \@lines if @lines;
	}
	return %src;
}

sub default_source
{
	my ($fsm_name, $lang, $files, $src) = @_;

	return if keys %$src; # some sources were found. nothing to do.
	
	for my $fn (@$files) {
		my $ft = $lang->guess_file_type( $fn );
		next unless $ft;
		my @bbs = $lang->bb_default( $ft );
		$src->{$fn} = [ map { \"$_" } @bbs ];
		warn "$fn: $ft: @bbs";
	}
}

sub write_source
{
	my ($fsm_name, $lang, $src) = @_;

	my $pref = $lang->bb_prefix( $fsm_name );
	my $suff = $lang->bb_suffix( $fsm_name );

	for my $fn (keys %$src) {
		rename( $fn, $fn.".bak" );
		open my $of, '>', $fn or die;
		for my $l ( @{$src->{$fn}} ) {
			if (ref $l) {
				my $bb = $$l;
				my (@g) = $lang->bb( $bb, $fsm{$fsm_name} );
				print $of $pref, $bb, ':begin', $suff, "\n";
				print $of $_, "\n" for @g;
				print $of $pref, $bb, ':end', $suff, "\n";
			}
			else {
				print $of "$l\n";
			}
		}
	}

}

for my $fsm_name (keys %fsm) {
	my $fsm = $fsm{$fsm_name};
	my $lang = lang::c->new();

	print "header: ".$fsm->{file_header}."\n";
	print "source: ".$fsm->{file_code}."\n";

	my (@l) = map { my $x=$_; $x=~s!"!!g; $x; } ($fsm->{file_header}, $fsm->{file_code});

	my %src = read_source( $fsm_name, $lang, @l );
	warn "read_source: @{[keys %src]}";
	default_source( $fsm_name, $lang, \@l, \%src );
	warn "default_source: @{[keys %src]}";
	write_source( $fsm_name, $lang, \%src );
}
