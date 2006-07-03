#########
# Author: dj3
# Maintainer: dj3
# Created: 2005-08-19
# Last Modified: 2005-09-02
# Builds DAS features from Gene Target mysql database of David Melvin

package Bio::Das::ProServer::SourceAdaptor::genetarget_db;

use strict;
use base qw(Bio::Das::ProServer::SourceAdaptor);
use Bio::Das::ProServer::SourceAdaptor;
use Data::Dumper;


#######################################################################################################
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'feature_id'   => '1.5',
			     'stylesheet' => '1.0',
			    };
}


#######################################################################################################
sub build_features {
  my ($self, $opts) = @_;
  my $seg     = $opts->{'segment'};
  my $start   = $opts->{'start'};
  my $end     = $opts->{'end'};
  my $startandend    = $start=~/^\d+$/ and $end=~/^\d+$/; 
  my $feature_id     = $opts->{'feature_id'};
  my $assembly       = $self->config->{'assembly'};
  my $goldenpath     = $self->config->{'goldenpath'};
  die "Need assembly or goldenpath e.g. mus_musculus_core_32_34 or NCBIM36 -- not both" unless (defined($assembly) xor defined($goldenpath));
  my $designtype     = $self->config->{'designtype'} || "O"; #e.g. O or LO
  my $pseudointra    = defined($self->config->{'pseudointra'})?$self->config->{'pseudointra'}:1; #e.g. 1 or 0
  my $pseudoends     = defined($self->config->{'pseudoends'})?$self->config->{'pseudoends'}:1; #e.g. 1 or 0
  my $mergenotes     = defined($self->config->{'mergenotes'})?$self->config->{'mergenotes'}:1; #e.g. 1 or 0
  my $skipleftjoin   = $self->config->{'skipleftjoin'} || 0; #skip orientation and Tm info - possible speedup

  #hack to restrict SQL queries to chromosomes and haplotyes, else we'd take too long and suffer timeouts.
  if (! $feature_id) {
    return if(CORE::length("$seg") > 4);
  }

  ($seg,$feature_id)=map{defined($_)? $self->transport->dbh->quote($_) :$_}($seg,$feature_id);#try to avoid SQL injection


  #alter SQL depending on type of query - by feature id, or by segment.
  #get all features associated with the design for which one feature is requested/in the requested range
  my $qbounds = $feature_id ? qq(
(SELECT DISTINCT DESIGN_ID FROM FEATURES WHERE FEATURE_ID=$feature_id) FA JOIN FEATURES F USING (DESIGN_ID)
)
    : $startandend ? qq(
(SELECT DISTINCT DESIGN_ID FROM FEATURES JOIN CHROMOSOME_DICT C USING (CHR_ID) WHERE C.name = $seg AND FEATURE_START<=$end AND FEATURE_END>=$start ) FA JOIN FEATURES F USING (DESIGN_ID)
)
      : "FEATURES F";
  #now get info on all those features, but also limit features to those for the correct assembly and of the right type.
  my $query   = qq(
SELECT C.name SEGMENT, F.*, T.DESCRIPTION TYPE
).($skipleftjoin?"":qq(
, D.DATA_ITEM ORIENT, D2.DATA_ITEM SEQ, D3.DATA_ITEM TM
)).qq(
FROM $qbounds
JOIN CHROMOSOME_DICT C USING (CHR_ID)
JOIN FEATURE_TYPE_DICT T ON F.FEATURE_TYPE=T.FEATURE_TYPE
JOIN DESIGNS S ON F.DESIGN_ID = S.DESIGN_ID
JOIN BUILD_INFO B ON S.BUILD_ID=B.BUILD_ID 
).(defined($assembly)?qq(
AND B.CORE_VERSION="$assembly"
):qq(
AND B.GOLDEN_PATH="$goldenpath"
)).($skipleftjoin?"":qq(
LEFT JOIN FEATURE_DATA D ON D.FEATURE_DATA_TYPE=1 AND F.FEATURE_ID=D.FEATURE_ID
LEFT JOIN FEATURE_DATA D2 ON D2.FEATURE_DATA_TYPE=2 AND F.FEATURE_ID=D2.FEATURE_ID
LEFT JOIN FEATURE_DATA D3 ON D3.FEATURE_DATA_TYPE=3 AND F.FEATURE_ID=D3.FEATURE_ID
)).qq(
WHERE ).($feature_id?"":qq(C.name = $seg AND )).qq( 
(T.DESCRIPTION LIKE "%\\_$designtype\\_%" OR T.DESCRIPTION LIKE "%\\_$designtype" )
ORDER BY F.FEATURE_START
                  );

#warn $query;
  my @results;
  foreach ( @{$self->transport->query($query)} ) {
    my $type = $_->{'TYPE'};
    my $group = $_->{'DESIGN_ID'};
    my $grouptype;
    $grouptype=$1 if ($type=~/^(\S+)_(L?O_\S+)$/);
    my %groups;
    $groups{$group}={'grouptype'=>"cko",'grouplabel'=>$group,'grouplinktxt'=>$group.' '.$designtype, 'grouplink'=>'http://www.sanger.ac.uk/cgi-bin/PostGenomics/mouse/genetarget/design?design_id='.$group.'&design_type='.$designtype};
    #$groups{$group."_".$grouptype}={'grouptype'=>$grouptype,'grouplabel'=>$group."_".$grouptype,'groupnote'=>"stuff about $group and $grouptype",'grouplink'=>["http://wibble/".$_->{'FEATURE_ID'},"http://wibble2"],'grouplinktxt'=>["wobble_".$_->{'FEATURE_ID'},"wobble2"]} if $grouptype;
    push @results, {
		    'segment'	=> $_->{'SEGMENT'},
		    'id'		=> $_->{'FEATURE_ID'},
		    'start'		=> $_->{'FEATURE_START'},
		    'end'		=> $_->{'FEATURE_END'},
				#'label'		=> $_->{'label'},
		    'score'		=> $_->{'TM'}||"",
		    'ori'		=> $_->{'ORIENT'}||"0",
				#'phase'		=> $_->{'phase'},
		    'type'		=> "genetarget:".$type,
		    'typecategory'	=> "knockout",
		    'method'	=> "genetarget",
		    'group'		=> \%groups,
				#'link'		=> $_->{'link_url'},
				#'linktxt'	=> $_->{'link_text'},
		    (exists $_->{'SEQ'}?('note'	=> $type.":".$_->{'SEQ'}):()),
				#'link'		=> {"http://foo1/".$_->{'FEATURE_ID'}=>"foo1_".$_->{'FEATURE_ID'},"http://foo2"=>"foo2"},
		   };
  }
#warn scalar(@results)." results";

  if ($mergenotes){
    my %groupnotes;
    foreach my $f (@results){
      if(exists($f->{'note'})){
	my ($group) = keys %{$f->{'group'}};
	$groupnotes{$group} .= $f->{'note'}." ";
	delete($f->{'note'});
      }
    }
    foreach my $f (@results){
      my ($group) = keys %{$f->{'group'}};
      $f->{'group'}{$group}{'groupnote'} = $groupnotes{$group} if $groupnotes{$group};
    }
  }
  

  my @pseudo=();
  #add pseudo features for benefit of current ensembl DAS - retreival and lox intra stuff, and end of range so group line drawn.
  if ($pseudoends or $pseudointra) {
    my %hashByGroup=();
    foreach my $f (@results) {
      push @{$hashByGroup{(keys %{$f->{group}})[0]}},$f;
    }
    while (my ($group,$gresults)=each %hashByGroup) {
      my @tmp= sort {$a->{start} <=> $b->{start}} grep {$_->{type}=~/(?:RETRIEVAL)|(?:LOXP)/}@$gresults;
      if ($pseudointra) {
	for (my $i=0; $i<$#tmp; $i+=2) {
	  my $tmpf = {%{$tmp[$i]}};
	  if (($tmpf->{end}+1)<($tmp[$i+1]{start})) {
	    $tmpf->{start}=$tmpf->{end}+1;
	    $tmpf->{end}=$tmp[$i+1]{start}-1;
	    $tmpf->{typecategory}="pseudo";
	    $tmpf->{type}=~s/(_[^_]+)(?:_[^_]+)?$/$1_INTRA/;
	    $tmpf->{id}="pseudo_".$tmpf->{start}."_".$tmpf->{end};
	    delete($tmpf->{score});
	    push @pseudo, $tmpf;
	  }
	}
      }
      if ($pseudoends && $startandend) {
	foreach my $limit ($start,$end) {
	  my $min=""; my $max="";
	  foreach my $f (@tmp) {
	    last if ($limit>=$f->{start})&&($limit<=$f->{end});
	    $min = $f->{start} unless $min && $f->{start}>$min;
	    $max = $f->{end} unless $max && $f->{end}<$max;
	  }
	  if ($min&&$max&&($min<$limit)&&($max>$limit)) {
	    push @pseudo, {ori=>0,group=>$group,segment=>$gresults->[0]->{segment},start=>$limit,end=>$limit,method=>"genetarget",type=>"genetarget:HIDDEN",typecategory=>"pseudo",id=>"pseudo_$limit\_$limit",};
	  }
	}
      }
    }
  }

  return (@results, @pseudo);
}
1;
