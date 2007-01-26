#########
# Author:        rmp
# Maintainer:    $Author: rmp $
# Created:       2004-02-16
# Last Modified: $Date: 2007/01/26 23:10:41 $
#
# Builds DAS features from Phenotypic Abnormalities Database
#
package Bio::Das::ProServer::SourceAdaptor::decipher;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor);

our $VERSION = do { my @r = (q$Revision: 2.50 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

sub length { 1; };

sub build_features {
  my ($self, $opts) = @_;
  my $seg           = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  my $consentcheck  = lc($self->config->{'consentcheck'} || 'yes');
  
  #########
  # pretty duff valid chromosome check, but catches most clone ids quickly
  #
  return if(CORE::length($seg) > 2);

  #########
  # retrieve patient data
  #
  my $qbounds = '';
  
  my @args   = ($seg, $seg, $seg, $seg);
  if($start && $end) {
    $qbounds  = 'AND sc.chr_start <= ? AND ec.chr_end >= ?';
    push @args, ($end, $start);
  }

  my $patientquery = qq(SELECT STRAIGHT_JOIN a.patient_id          AS id,
			       p.submitter_groupname AS curator,
			       p.project_id          AS project_id,
			       f.mean_ratio          AS type,
			       f.type_id             AS origin,
			       sc.chr_end            AS soft_start,
			       ec.chr_start          AS soft_end,
			       hsc.chr_start         AS hard_start,
			       hec.chr_end           AS hard_end
			FROM   array           a,
                               patient         p,
                               patient_feature f,
                               clone           sc,
                               clone           ec,
                               clone           hsc,
                               clone           hec
			WHERE  p.consent        = 'Y'
			AND    f.array_id       = a.id
			AND    a.patient_id     = p.id
			AND    sc.name          = f.soft_start_clone_name
			AND    ec.name          = f.soft_end_clone_name
			AND    hsc.name         = f.hard_start_clone_name
			AND    hec.name         = f.hard_end_clone_name
			AND    sc.chr           = ?
			AND    ec.chr           = ?
			AND    hsc.chr          = ?
			AND    hec.chr          = ?
                        AND    sc.arraytype_id  = a.arraytype_id
			AND    ec.arraytype_id  = a.arraytype_id
			AND    hsc.arraytype_id = a.arraytype_id
			AND    hec.arraytype_id = a.arraytype_id $qbounds
                       	GROUP BY a.patient_id,sc.name,ec.name
			ORDER BY a.patient_id);

  my $plinktmpl = $self->config->{'patientlink'}       || '%s:%s';
  my $slinktmpl = $self->config->{'syndromelink'}      || '%s:%s';
  my $tlinktmpl = $self->config->{'translocationlink'} || '%s:%s:%s';
  my @features  = ();
  my $fid       = 1;
  my $gid       = 1;

  for my $patient (@{$self->transport->query($patientquery, @args)}) {
    my $id             = $patient->{'id'};
    my $phenotypequery = qq(SELECT description
			    FROM   phenotype c, patient_class pc, patient p
			    WHERE  pc.patient_id = ?
			    AND    pc.class_id   = c.id
			    AND    p.id          = pc.patient_id
			    @{[($consentcheck eq 'yes')?q(AND p.consent = 'Y'):'']});

    my $lbl          = sprintf('%08d',  $id); #sr5: need to remove the center codes:
    my $classes      = $self->transport->query($phenotypequery, $id);

    my $classtxt     = join(', ', map { $_->{'description'} } @{$classes});
    my $chr_interval = $patient->{'soft_end'} - $patient->{'soft_start'};

    #########
    # feature
    #
    my ($hardstart, $hardend) = ($patient->{'hard_start'}, $patient->{'hard_end'});
    ($hardend, $hardstart)    = ($hardstart, $hardend) if($hardend < $hardstart);

    my $mr = $patient->{'type'};
    my $cc = '';
    if($mr < -1) {
      $cc = 0;
    } elsif($mr >= -1 && $mr < 0) {
      $cc = 1;
    } elsif($mr == 0) {
      $cc = 2;
    } elsif($mr >= 0  && $mr < 0.58) {
      $cc = 3;
    } elsif($mr >= 0.58 && $mr < 1) {
      $cc = 4;
    } elsif($mr >= 1) {
      $cc = 5;
    }

    push @features, {
		     'id'           => $fid++,
		     'label'        => $lbl,
		     'type'         => sprintf('decipher:%s:%s:hard',
					       ($patient->{'origin'} == 9)?'poly':'novel',
					       ($cc < 2)?'del':'ins'),
		     'method'       => 'decipher',
		     'start'        => $hardstart,
		     'end'          => $hardend,
		     'ori'          => ($cc < 2)?'-':'+',
		     'group'        => $lbl, 
		     'grouplink'    => sprintf($plinktmpl, $patient->{'project_id'}, $id),
		     'grouplinktxt' => 'Patient Report',
		     'typecategory' => 'decipher',
		     'link'         => sprintf($plinktmpl, $patient->{'project_id'}, $id),
		     'linktxt'      => 'Patient Report',
		     'note'         => $classtxt || '',
		     'groupnote'    => $classtxt || '',
		    };

    #########
    # fuzzy, surrounding feature
    #
    my ($softstart, $softend) = ($patient->{'soft_start'}, $patient->{'soft_end'}); #need to fix these error bars - also need to deal with overlaps i.e. upstream + downstream clones.
    ($softend, $softstart)    = ($softstart, $softend) if($softend < $softstart);

    push @features, {
		     'id'           => $fid++,
		     'type'         => sprintf('decipher:%s:%s:soft',
					       ($patient->{'origin'} == 9)?'poly':'novel',
					       ($cc < 2)?'del':'ins'),
		     'method'       => 'decipher',
		     'start'        => $softstart,
		     'end'          => $softend,
		     'link'         => sprintf($plinktmpl, $patient->{'project_id'}, $id),
		     'linktxt'      => 'Patient Report',
		     'note'         => $classtxt,
		     'ori'          => ($cc < 2)?'-':'+',
		     'group'        => $lbl,
		     'grouplink'    => sprintf($plinktmpl, $patient->{'project_id'}, $id),
		     'grouplinktxt' => 'Patient Report',
		     'typecategory' => 'decipher',
		     'groupnote'    => $classtxt || '',
		    };
    $gid++;
  }

  #########
  # retrieve
  #
  
  my $syndromequery = qq(SELECT ks.id                AS id,
			        ks.short_description AS description,
			        f.copy_number        AS type,
			        sc.chr_start         AS hard_start,
			        ec.chr_end           AS hard_end
			 FROM   clone            sc,
                                clone            ec,
                                syndrome_feature f,
                                syndrome         ks
			 WHERE  ks.id           = f.syndrome_id
			 AND    sc.name         = f.start_clone_name
			 AND    ec.name         = f.end_clone_name
			 AND    sc.chr          = ?
			 AND    ec.chr          = ?
			 AND    sc.arraytype_id = f.arraytype_id
			 AND    ec.arraytype_id = f.arraytype_id $qbounds
			 GROUP BY ks.id,sc.name,ec.name
			 ORDER BY ks.id);

  my $phenotypequery = qq(SELECT description
			  FROM   phenotype c,
                                 syndrome_class ksc
			  WHERE  ksc.syndrome_id = ?
			  AND    ksc.class_id    = c.id);

  @args = ();
  push @args, ($end, $start) if($qbounds);
  for my $syndrome (@{$self->transport->query($syndromequery, $seg, $seg, @args)}) {
    my $lbl          = $syndrome->{'description'};
    my $id           = $syndrome->{'id'};
    my $classes      = $self->transport->query($phenotypequery, $id);
    my $classtxt     = join(', ', map { $_->{'description'} } @{$classes});
    my $chr_interval = $syndrome->{'hard_end'} - $syndrome->{'hard_start'};

    #########
    # feature
    #
    my ($hardstart, $hardend) = ($syndrome->{'hard_start'}, $syndrome->{'hard_end'});
    ($hardend, $hardstart)    = ($hardstart, $hardend) if($hardend < $hardstart);
    push @features, {
		     'id'           => $fid++,
		     'label'        => $lbl,
		     'type'         => sprintf('decipher:known:%s', ($syndrome->{'type'} < 2)?'del':'ins'),
		     'method'       => 'decipher',
		     'start'        => $hardstart,
		     'end'          => $hardend,
		     'ori'          => ($syndrome->{'type'} < 2)?'-':'+',
		     'note'         => $classtxt,
		     'typecategory' => 'decipher',
		     'link'         => sprintf($slinktmpl, $id),
		     'linktxt'      => 'Syndrome Report',
		    };
  }

  ###########################################################################
  #Translocation section ...
  # Author:        SR5
  # Maintainer:    SR5
  # Created:       2006-05-22
  ###########################################################
 
  my $translocationquery = qq(SELECT t.patient_id            AS patient_id,
                                     sc.chr                  AS chr,
                                     sc.chr_start            AS sc_start,
                                     sc.chr_end              AS sc_end,
                                     ec.chr_start            AS ec_start,
                                     ec.chr_end              AS ec_end,
                                     tc.start_clone_name     AS start_clone_name,
                                     tc.end_clone_name       AS end_clone_name,
                                     sc.strand               AS sc_strand,
                                     ec.strand               AS ec_strand,
                                     tc.id                   AS tc_id,
                                     t.karyotype             AS karyotype,
                                     t.id                    AS trans_id,
                                     t.translocation_type_id AS type_id,
                                     b.position              AS position,
                                     b.topology              AS topology,
                                     tf.strand               AS tf_strand,
                                     p.project_id            AS project_id
                              FROM   translocation_clone    tc,
                                     translocation          t,
                                     breakpoint             b,
                                     patient                p,
                                     translocation_features tf,
                                     clone                  sc,
                                     clone                  ec
                              WHERE  t.patient_id                 = p.id
                              AND    tf.translocation_clone_id    = tc.id
                              AND    tc.translocation_id          = t.id
                              AND    tc.start_clone_name          = sc.name
                              AND    tc.end_clone_name            = ec.name
                              AND    sc.arraytype_id              = tc.arraytype_id
                              AND    ec.arraytype_id              = tc.arraytype_id
                              AND    b.translocation_clone_id     = tc.id
                              AND    p.consent                    = 'Y'
                              AND    sc.chr                       = ?
                              AND    ec.chr                       = ?
                              $qbounds
                              GROUP BY tc.id
                              ORDER BY p.id,t.id);

  my %t_hash;
  my $patient_trans_query = qq(SELECT t.patient_id    AS p_id,
                                      sc.chr          AS chr,
                                      sc.chr_start    AS sc_start,
                                      sc.chr_end      AS sc_end,
                                      ec.chr_start    AS ec_start,
                                      ec.chr_end      AS ec_end,
                                      tc.id           AS translocation_clone_id,
                                      t.id            AS trans_id,
                                      t.translocation_type_id AS type_id
                               FROM   translocation_clone    tc,
                                      translocation          t,
                                      patient                p,
                                      translocation_features tf,
                                      clone                  sc,
                                      clone                  ec
                               WHERE  t.patient_id                 = p.id
                               AND    tf.translocation_clone_id    = tc.id
                               AND    tc.translocation_id          = t.id
                               AND    tc.start_clone_name          = sc.name
                               AND    tc.end_clone_name            = ec.name
                               AND    sc.arraytype_id              = tc.arraytype_id
                               AND    ec.arraytype_id              = tc.arraytype_id
                               GROUP BY tc.id);

  for my $patient_trans (@{$self->transport->query($patient_trans_query)}) {
    my $start_view = $patient_trans->{'sc_start'} - 250000; # 250000 is to centre the feature within cytoview.
    my $end_view   = $patient_trans->{'sc_end'}   + 250000; #check this!!
    push (@{$t_hash{$patient_trans->{'p_id'}}{$patient_trans->{'trans_id'}} },
	  {
	   'link'       => sprintf($tlinktmpl, $patient_trans->{'chr'}, $start_view, $end_view),
	   'label'      => 'Chromosome ' . $patient_trans->{'chr'} . ' view',
	  });
  }
 @args = ();
  push @args, ($end, $start) if($qbounds);
  for my $translocation (@{$self->transport->query($translocationquery, $seg, $seg, @args)}) {
    my $id              = $translocation->{'id'};
    my $patient_id      = $translocation->{'patient_id'};
    my $tc_id           = $translocation->{'tc_id'};
    my $trans_id        = $translocation->{'trans_id'};
    my $type_id         = $translocation->{'type_id'};
    my $start_clone     = $translocation->{'start_clone_name'};
    my $end_clone       = $translocation->{'end_clone_name'};
    my $chr             = $translocation->{'chr'};
    my $arraytype_id    = $translocation->{'arraytype_id'};
    my ($sc_tstart, $sc_tend) =($translocation->{'sc_start'},$translocation->{'sc_end'});
    my ($ec_tstart, $ec_tend) =($start_clone ne $end_clone)?($translocation->{'ec_start'},$translocation->{'ec_end'}):("","");#

    my $typequery       = $self->transport->query(qq(SELECT description
                                                     FROM   translocation_type
                                                     WHERE  id = ?),
						     $type_id);

    my $typetxt      = join(', ', map { $_->{'description'} } @{$typequery});
    my $lbl          = sprintf('%08d', $patient_id);
    my $tlbl         = sprintf("%s%08d", "T_", $patient_id);
    my $invlbl       = sprintf("%s%08d", "I_", $patient_id);
    my $classes      = $self->transport->query(qq(SELECT description
						  FROM   phenotype c, patient_class pc, patient p
       					          WHERE  pc.patient_id = ?
						  AND    pc.class_id   = c.id
						  AND    p.id          = pc.patient_id),
					       $patient_id);

    my $classtxt     = join(', ', map { $_->{'description'} } @{$classes});
#    my $chr_interval = $translocation->{'end'} - $translocation->{'end'}; #
    my $chr_view     = 1000; #1kb - however it may need altering

    #########
    # feature
    # the start and end positions are identified using the following principles...
    # with an addition of 1kb on either side to view within Decipher
    #Or should this be greater i.e. 1Mb

    my($bpstart, $bpstart_two,$bpend,$bpend_two, $strand, $strand_two);
    my $topology    = $translocation->{'topology'};
    my $position    = $translocation->{'position'};
    my $tfstrand    = $translocation->{'tf_strand'};
    $strand         = $translocation->{'sc_strand'};
    $strand_two     = $translocation->{'ec_strand'};
    
    #############################
    #The logic below determines the size of the breakpoint region and the clone view!!
    #################################
    if($topology) {
      if($topology =~ /upstream/i) {
	if($strand<0) {
	  $bpstart     = $sc_tend-$position;
	}else{
	  $bpstart     = $sc_tstart+$position-1;
	}
	if($strand_two<0){
	  $bpstart_two = ($ec_tend && $type_id == 6)?$ec_tend-$position:"";
	}else{
	  $bpstart_two = ($ec_tstart && $type_id == 6)?$ec_tstart+$position-1:"";
	}
      }elsif($topology =~ /downstream/i) {
	if($strand<0){
	  $bpend     = $sc_tend-$position;
	}else{ 
	  $bpend     = $sc_tstart+$position-1;
	}
	if($strand_two<0){
	  $bpend_two = ($ec_tend && $type_id == 6)?$ec_tend-$position:"";
	}else{
	  $bpend_two = ($ec_tstart && $type_id == 6)?$ec_tend+$position-1:"";
	}
      }
    }
    else{
      if((($start_clone ne $end_clone) || ($position == 0)) && ($type_id != 6)) { 
	#Not very sure about this loop!?
	$bpstart = $sc_tstart;
	$bpend   = $sc_tend;
      }else {
	if($strand<0) {
	  $bpstart = $sc_tend-$position;
	}else{
	  $bpstart = $sc_tstart+$position-1;
	}
	if($strand_two<0){
	  $bpstart_two =($ec_tend && $type_id == 6)?$ec_tend-$position:"";
	}
	else{
	  $bpstart_two = ($ec_tend && $type_id == 6)?$ec_tend+$position-1:"";
	}
	$bpend     = $bpstart;
	$bpend_two = $ec_tend;
      }
    }	
    
    $bpend   ||= $bpstart+1 if($bpstart);
    $bpstart   = $bpstart-$chr_view;
    $bpend     = $bpend+$chr_view;
    
    if(($bpstart_two && $bpend_two) && ($type_id == 6)){
      $bpend_two   ||= $bpstart_two+1 if($bpstart_two);
      $bpstart_two   = $bpstart_two-$chr_view;
      $bpend_two     = $bpend_two+$chr_view;
    }
    my $clone_start  = $sc_tstart; 
    my $clone_end    =($type_id == 6 && $start_clone ne $end_clone)?$ec_tend:$sc_tend;
    if($type_id == 6){
      print STDERR "BPSTART_one:$bpstart and BPEND_one: $bpend\n";
      print STDERR "BPSTART:$bpstart_two and CLONE START: $clone_start\n";
      print STDERR "BPEND: $bpend_two and CLONE END: $clone_end\n";
      print STDERR "CLONES: $start_clone ($sc_tstart, $sc_tend) AND $end_clone ($ec_tstart, $ec_tend)";
    }
    ###################
    # Use the hash created above to create links to view translocation linked chromosomes.
    #
    my $ref_aoh  = $t_hash{$patient_id}{$trans_id};
    my @links  = ();
    my @labels = ();
    for my $v(@$ref_aoh){
      push @links,  $v->{'link'}, sprintf($plinktmpl, $translocation->{'project_id'}, $patient_id);
      push @labels, $v->{'label'}, 'Patient Report';
    }
    

    push @features, {
		     'id'           => $fid++,
		     'label'        => $lbl,
		     'type'         => sprintf('decipher:%s:%s:breakpoint', 'translocation', $typetxt),
		     'method'       => 'decipher',
		     'start'        => $bpstart,
		     'end'          => $bpend,
		     'ori'          => ($strand<0)?'-':'+',
		     'group'        => $tlbl,
		     'grouplink'    => [@links],
		     'grouplinktxt' => [@labels],
		     'typecategory' => 'decipher',
		     'link'         => sprintf($plinktmpl, $translocation->{'project_id'}, $patient_id),
		     'linktxt'      => 'Patient Translocation Report',
		     'note'         => $classtxt || '',
		     'groupnote'    => $classtxt || '',
		    };

    push @features, {
		     'id'           => $fid++,
		     'label'        => $lbl,
		     'type'         => sprintf('decipher:%s:%s:clone', 'translocation', $typetxt),
		     'method'       => 'decipher',
		     'start'        => $clone_start,
		     'end'          => $clone_end,
		     'ori'          => ($strand<0)?'-':'+',
		     'group'        => $tlbl,
		   # 'grouplink'    => [@links],
		   # 'grouplinktxt' => [@labels],
		     'grouplink'    => sprintf($plinktmpl, $translocation->{'project_id'}, $patient_id),
		     'grouplinktxt' => 'Patient Translocation Report',
		     'typecategory' => 'decipher',
		     'link'         => sprintf($plinktmpl, $translocation->{'project_id'}, $patient_id),
		     'linktxt'      => 'Patient Translocation Report',
		     'note'         => $classtxt || '',
		     'groupnote'    => $classtxt || '',
		    };
    
    if($bpstart_two && $bpend_two){
      push @features, {
		       'id'           => $fid++,
		       'label'        => $lbl,
		       'type'         => sprintf('decipher:%s:%s:breakpoint2', 'translocation', $typetxt),
		       'method'       => 'decipher',
		       'start'        => $bpstart_two,
		       'end'          => $bpend_two,
		       'ori'          =>($strand_two<0)?'-':'+',
		       'group'        => $tlbl,
		       'typecategory' => 'decipher',
		       'link'         => sprintf($plinktmpl, $translocation->{'project_id'}, $patient_id),
		       'linktxt'      => 'Patient Translocation Report',
		       'note'         => $classtxt || '',
		       'groupnote'    => $classtxt || '',
		      };
    }
    
    $gid++;
  }
  return @features;
}

1;
