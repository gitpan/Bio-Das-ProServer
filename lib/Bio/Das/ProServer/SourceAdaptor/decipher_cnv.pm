#Author: sr5
#Maintainer:sr5
#Created: 2007-05-10
#Purpose: Separate DECIPHER track displaying ONLY user defined copy number variants from the DECIPHER database 
#Most of code base was obtained from decipher.pm sourceadaptor for quick production
#Also note that this DAS source utililises the DECIPHER stylesheet!!!

package Bio::Das::ProServer::SourceAdaptor::decipher_cnv;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor);


our $VERSION = do { my @r = (q$Revision: 1.2 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}


sub build_features {
  my ($self, $opts) = @_;
  my $seg           = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  my $consentcheck  = lc($self->config->{'consentcheck'} || 'yes');

 return if(CORE::length($seg) > 2);

#User defined segments...
  
  my $qbounds = '';
  
  my @args   = ($seg, $seg, $seg, $seg);
  if($start && $end) {
    $qbounds  = 'AND sc.chr_start <= ? AND ec.chr_end >= ?';
    push @args, ($end, $start);
  }

  #########
  # retrieve DECIPHER patient data within a specific segement.
  #

  my $patientquery = qq(SELECT STRAIGHT_JOIN a.patient_id    AS id,
			       p.submitter_groupname         AS curator,
			       p.project_id                  AS project_id,
			       pf.mean_ratio                 AS type,
			       pf.type_id                    AS origin,
			       sc.chr_end                    AS soft_start,
			       ec.chr_start                  AS soft_end,
			       hsc.chr_start                 AS hard_start,
			       hec.chr_end                   AS hard_end
			FROM   array           a,
                               patient         p,
                               patient_feature pf,
                               clone           sc,
                               clone           ec,
                               clone           hsc,
                               clone           hec,
                               feature_type    ft
			WHERE  p.consent        = 'Y'
                        AND    p.parent        != 'Y'
			AND    pf.array_id      = a.id
			AND    a.patient_id     = p.id
			AND    sc.name          = pf.soft_start_clone_name
			AND    ec.name          = pf.soft_end_clone_name
			AND    hsc.name         = pf.hard_start_clone_name
			AND    hec.name         = pf.hard_end_clone_name
                        AND    ft.id            = pf.type_id
                        AND    (ft.description   like '%de novo%' OR ft.description   like '%cnv%')
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

    my $lbl          = sprintf('%08d',  $id); 
    my $classes      = $self->transport->query($phenotypequery, $id);

    my $classtxt     = join(', ', map { $_->{'description'} } @{$classes});
    my $chr_interval = $patient->{'soft_end'} - $patient->{'soft_start'};

    #########
    # Build features for das source display ...
    # Patient data builds two features foreach patient - hard start and hard end  displayed as a box in the view ...
    # and soft start and soft end ( i.e. flanking positions) displayed as the extended lines from the box.
    # Note: In certain instances the arms may not be displayed because the flanking clones start or end positions may be found
    # within the start and end feature.
 
    #Start and End ...
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
		     'method'       => 'decipher_cnv',
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
    # fuzzy, surrounding feature i.e. flank clone regions ..
    #
    my ($softstart, $softend) = ($patient->{'soft_start'}, $patient->{'soft_end'}); #need to fix these error bars - also need to deal with overlaps i.e. upstream + downstream clones.
    ($softend, $softstart)    = ($softstart, $softend) if($softend < $softstart);
    
    push @features, {
		     'id'           => $fid++,
		     'type'         => sprintf('decipher:%s:%s:soft',
					       ($patient->{'origin'} == 9)?'poly':'novel',
					       ($cc < 2)?'del':'ins'),
		     'method'       => 'decipher_cnv',
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
  return @features;
}

1;
