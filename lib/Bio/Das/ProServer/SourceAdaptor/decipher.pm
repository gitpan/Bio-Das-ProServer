#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2004-02-16
# Last Modified: 2005-06-22 rmp (for symposium)
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
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

sub length { 1;};

sub build_features {
  my ($self, $opts) = @_;
  my $seg           = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  my $consentcheck  = lc($self->config->{'consentcheck'} || "yes");

  #########
  # pretty duff valid chromosome check, but catches most clone ids quickly
  #
  return if(CORE::length("$seg") > 2);

  #########
  # retrieve patient data
  #
  my $qbounds      = ($start && $end)?qq(AND c1.chr_start <= '$end' AND c2.chr_end >= '$start'):"";
  my $patientquery = qq(SELECT a.patient_id          AS id,
			       p.submitter_groupname AS curator,
			       p.project_id          AS project_id,
			       f.mean_ratio          AS type,
			       f.type_id             AS origin,
			       c1.chr_end            AS soft_start,
			       c2.chr_start          AS soft_end,
			       c3.chr_start          AS hard_start,
			       c4.chr_end            AS hard_end
			FROM   clone c1, clone c2, clone c3, clone c4, patient_feature f, array a, patient p
			WHERE  p.consent       = 'Y'
			AND    f.array_id      = a.id
			AND    a.patient_id    = p.id
			AND    c1.name         = f.soft_start_clone_name
			AND    c2.name         = f.soft_end_clone_name
			AND    c3.name         = f.hard_start_clone_name
			AND    c4.name         = f.hard_end_clone_name
			AND    c1.chr          = '$seg'
			AND    c2.chr          = '$seg'
			AND    c3.chr          = '$seg'
			AND    c4.chr          = '$seg'
			AND    c1.arraytype_id = a.arraytype_id
			AND    c2.arraytype_id = a.arraytype_id
			AND    c3.arraytype_id = a.arraytype_id
			AND    c4.arraytype_id = a.arraytype_id $qbounds
			GROUP BY a.patient_id,c1.name,c2.name
			ORDER BY a.patient_id);

  my $plinktmpl = $self->config->{'patientlink'}  || "%s:%s";
  my $slinktmpl = $self->config->{'syndromelink'} || "%s:%s";
  my @features  = ();
  my $fid       = 1;
  my $gid       = 1;

  for my $patient (@{$self->transport->query($patientquery)}) {
    my $lbl          = sprintf("%s%08d", $patient->{'curator'}, $patient->{'id'});
    my $id           = $patient->{'id'};
    my $classes      = $self->transport->query(qq(SELECT description
						  FROM   phenotype c, patient_class pc, patient p
						  WHERE  pc.patient_id = '$id'
						  AND    pc.class_id   = c.id
						  AND    p.id          = pc.patient_id
						  @{[($consentcheck eq "yes")?"AND p.consent = 'Y'":""]}));
    my $classtxt     = join(", ", map { $_->{'description'} } @{$classes});
    my $chr_interval = $patient->{'soft_end'} - $patient->{'soft_start'};

    #########
    # feature
    #
    my ($hardstart, $hardend) = ($patient->{'hard_start'}, $patient->{'hard_end'});
    ($hardend, $hardstart)    = ($hardstart, $hardend) if($hardend < $hardstart);

    my $mr = $patient->{'type'};
    my $cc = "";
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
		     'type'         => sprintf("decipher:%s:%s:hard", ($patient->{'origin'} == 9)?"poly":"novel", ($cc < 2)?"del":"ins"),
		     'method'       => "decipher",
		     'start'        => $hardstart,
		     'end'          => $hardend,
		     'ori'          => ($cc < 2)?"-":"+",
		     'group'        => $lbl, #"$id.$gid",
		     'grouplink'    => sprintf($plinktmpl, $patient->{'project_id'}, $id),
		     'grouplinktxt' => 'Patient Report',
		     'typecategory' => 'decipher',
		     'link'         => sprintf($plinktmpl, $patient->{'project_id'}, $id),
		     'linktxt'      => "Patient Report",
		     'note'         => $classtxt || "",
		     'groupnote'    => $classtxt || "",
		    };

    #########
    # fuzzy, surrounding feature
    #
    my ($softstart, $softend) = ($patient->{'soft_start'}, $patient->{'soft_end'});
    ($softend, $softstart)    = ($softstart, $softend) if($softend < $softstart);
    push @features, {
		     'id'           => $fid++,
		     'type'         => sprintf("decipher:%s:%s:soft", ($patient->{'origin'} == 9)?"poly":"novel", ($cc < 2)?"del":"ins"),
		     'method'       => "decipher",
		     'start'        => $softstart,
		     'end'          => $softend,
		     'link'         => sprintf($plinktmpl, $patient->{'project_id'}, $id),
		     'linktxt'      => "Patient Report",
		     'note'         => $classtxt,
		     'ori'          => ($cc < 2)?"-":"+",
		     'group'        => $lbl, #"$id.$gid",
		     'grouplink'    => sprintf($plinktmpl, $patient->{'project_id'}, $id),
		     'grouplinktxt' => 'Patient Report',
		     'typecategory' => 'decipher',
		     'groupnote'    => $classtxt || "",
		    };
    $gid++;
  }

  #########
  # retrieve
  #
  my $syndromequery = qq(SELECT ks.id                AS id,
			        ks.short_description AS description,
			        f.copy_number        AS type,
			        c1.chr_start         AS hard_start,
			        c2.chr_end           AS hard_end
			 FROM   clone c1, clone c2, syndrome_feature f, syndrome ks
			 WHERE  ks.id   = f.syndrome_id
			 AND    c1.name = f.start_clone_name
			 AND    c2.name = f.end_clone_name
			 AND    c1.chr  = '$seg'
			 AND    c2.chr  = '$seg'
			 AND    c1.arraytype_id = f.arraytype_id
			 AND    c2.arraytype_id = f.arraytype_id $qbounds
			 GROUP BY ks.id,c1.name,c2.name
			 ORDER BY ks.id);

  for my $syndrome (@{$self->transport->query($syndromequery)}) {
    my $lbl          = $syndrome->{'description'};
    my $id           = $syndrome->{'id'};
    my $classes      = $self->transport->query(qq(SELECT description
						  FROM   phenotype c, syndrome_class ksc
						  WHERE  ksc.syndrome_id = '$id'
						  AND    ksc.class_id          = c.id));
    my $classtxt     = join(", ", map { $_->{'description'} } @{$classes});
    my $chr_interval = $syndrome->{'hard_end'} - $syndrome->{'hard_start'};

    #########
    # feature
    #
    my ($hardstart, $hardend) = ($syndrome->{'hard_start'}, $syndrome->{'hard_end'});
    ($hardend, $hardstart)    = ($hardstart, $hardend) if($hardend < $hardstart);
    push @features, {
		     'id'           => $fid++,
		     'label'        => $lbl,
		     'type'         => sprintf("decipher:known:%s", ($syndrome->{'type'} < 2)?"del":"ins"),
		     'method'       => "decipher",
		     'start'        => $hardstart,
		     'end'          => $hardend,
		     'ori'          => ($syndrome->{'type'} < 2)?"-":"+",
		     'note'         => $classtxt,
		     'typecategory' => 'decipher',
		     'link'         => sprintf($slinktmpl, $id),
		     'linktxt'      => "Syndrome Report",
		    };
  }

  ###########################################################################
  #Translocation section ...
  # Author:        SR5
  # Maintainer:    SR5
  # Created:       2006-05-22
  ###########################################################
  my $translocationquery = qq(SELECT p.id             AS patient_id,
                              p.project_id            AS project_id,
                              p.submitter_groupname   AS curator,
                              tc.id                   AS tc_id,
                              t.id                    AS trans_id,
                              tc.start_clone_name     AS start_clone,
                              tc.end_clone_name       AS end_clone, 
                              tc.chr_start            AS start, 
                              tc.chr_end              AS end, 
                              tc.chromosome           AS chromosome, 
                              tc.arraytype_id         AS arraytype_id,
                              t.translocation_type_id AS type_id,
                              t.karyotype             AS karyotype, 
                              b.position              AS position,
                              b.topology              AS  topology,
                              tf.strand               AS tf_strand
                              FROM  translocation t, translocation_clone tc, patient p, translocation_type tt, translocation_features tf, breakpoint b
                              WHERE t.patient_id = p.id
                              AND b.translocation_clone_id = tc.id
                              AND tc.chromosome  = '$seg'
                              AND tf.translocation_id = t.id
                              AND tc.translocation_id = t.id
                              AND tt.id = t.translocation_type_id
                              GROUP BY p.id
                              ORDER BY p.id,t.id);
  
  for my $translocation (@{$self->transport->query($translocationquery)}){
    my $id              = $translocation->{'id'};
    my $patient_id      = $translocation->{'patient_id'};
    my $tc_id           = $translocation->{'tc_id'};
    my $trans_id        = $translocation->{'trans_id'};
    my $type_id         = $translocation->{'type_id'};
    my $start_clone     = $translocation->{'start_clone'};
    my $arraytype_id    = $translocation->{'arraytype_id'};
    my $inversion;
    #    my $inversion       = $translocation->{'inversion'};
    my ($tstart, $tend) = ($translocation->{'start'}, $translocation->{'end'});
    my $typequery            = $self->transport->query(qq(SELECT description
                                                  FROM translocation_type
                                                  WHERE id = $type_id
                                                  ));
    my $typetxt      = join(", ", map { $_->{'description'} } @{$typequery});
    my $lbl          = sprintf("%s%08d", $translocation->{'curator'}, $translocation->{'patient_id'});
    my $classes      = $self->transport->query(qq(SELECT description
						  FROM   phenotype c, patient_class pc, patient p
						  WHERE  pc.patient_id = '$patient_id'
						  AND    pc.class_id   = c.id
						  AND    p.id          = pc.patient_id
						 ));
    
    my $classtxt     = join(", ", map { $_->{'description'} } @{$classes});
    my $chr_interval = $translocation->{'end'} - $translocation->{'start'}; #not sure about this!!!
    my $chr_view     = 1000; #1kb - however it may need altering
    #########
    # feature
    ##the start and end positions are identified using the following principles...
    # with an addition of 1kb on either side to view within Decipher
    
    my($bpstart, $bpend, $strand);
    my $topology    = $translocation->{'topology'};
    my $position    = $translocation->{'position'};
    my $bpstrand    = $translocation->{'tf_strand'};
    
    if ($topology){
      $strand = $bpstrand;
      if($topology =~ /upstream/i) {
	if($strand<0) {
	  $bpstart = $tend-$position;
	} else {
	  $bpstart = $tstart+$position-1;
	}
      } elsif($topology =~ /downstream/i) {
	if($strand<0){
	  $bpend = $tend-$position;
	} else {
	  $bpend = $tstart+$position-1;
	}
      }
    } else {
      my $strandquery   = $self->transport->query(qq(SELECT strand AS strand
                                                     FROM  clone
                                                     WHERE name       = '$start_clone'
                                                     AND arraytype_id = '$arraytype_id'
                                                    ));
      $strand = join(", ", map { $_->{'description'} } @{$strandquery});
      if($strand<0) {
	$bpstart = $tend-$position;
      } else {
	$bpstart = $tstart+$position-1;
      }
      $bpend   = $bpstart;
    }
    $bpend ||= $bpstart+1 if($bpstart); #???
    $bpstart = $bpstart-$chr_view;
    $bpend   = $bpend+$chr_view;
    my $type;
    if($trans_id){
      $type ="translocation";
    }elsif($inversion){
      $type = "inversion";
    }
      push @features, {
		       'id'           => $fid++,
		       'label'        => $lbl,
		       'type'         => sprintf("decipher:%s:%s",($type),($typetxt)),
		       'method'       => "decipher",
		       'start'        => $bpstart,
		       'end'          => $bpend,
		       'ori'          => ($strand < 0 )?"-":"+",
		       'group'        => $lbl,
		       'grouplink'    => sprintf($plinktmpl, $translocation->{'project_id'}, $patient_id),
		       'grouplinktxt' => 'Patient Translocation Report',
		       'typecategory' => 'decipher',
		       'link'         => sprintf($plinktmpl, $translocation->{'project_id'}, $patient_id),
		       'linktxt'      => "Patient Translocation Report",
		       'note'         => $classtxt || "",
		       'groupnote'    => $classtxt || "",
		      };
    
  }
  
  return @features;
}

1;
