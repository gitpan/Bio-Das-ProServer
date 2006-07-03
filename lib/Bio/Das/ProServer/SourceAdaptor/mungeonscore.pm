#########
# Author: dj3 
# Maintainer: dj3
# Created: 2005-10-27
# Last Modified: 2006-02-24
# Changes stylesheet creating extra feature types depending on score[color,height][min,max] in the original stylesheet, also changes feature types on the fly according to the festure's score

package Bio::Das::ProServer::SourceAdaptor::mungeonscore;

use strict;
use vars qw(@ISA);
use Storable qw(dclone);
use Bio::DasLite;
use Data::Dumper;
use Bio::Das::ProServer::SourceAdaptor::proxy;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor::proxy);


################################################################################
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

sub das_stylesheet {
  my $self = shift;
  my $ncolors =  defined(${$self->config}{'ncolors'})?$self->config->{'ncolors'}:5;
  my $das = Bio::DasLite->new({
			       'dsn' => $self->config->{'sourcedsn'},
			      });
  my $stylesheethash=[values %{$das->stylesheet}]->[0][0];
  for my $ch (@{$stylesheethash->{'category'}}) {
    my $cat =$ch->{'category_id'};
    my @newth =();
    #for all glyphs with scoreheightmax, scoreheightmin and  height defined create new types with the same glyph but many heights
    for my $th (@{$ch->{'type'}}){
      my ($scoreheightmax, $scoreheightmin, $height) =map{[(values %{$th->{'glyph'}->[0]})]->[0]->[0]->{$_}} qw(scoreheightmax scoreheightmin height);
      if(defined($scoreheightmax) and defined($scoreheightmin) and defined($height)){
	for my $h (1 .. int($height)){
	  my $newth =dclone($th);
	  $newth->{'type_id'}.="_$h";
	  my $glyphhashref = [(values %{$newth->{'glyph'}->[0]})]->[0]->[0];
          $glyphhashref->{'height'}=$h;
	  $glyphhashref->{'yoffset'}=($h-$height)/2;
          $glyphhashref->{'zindex'}=$height-$h unless exists $glyphhashref->{'zindex'};
          delete $glyphhashref->{'scoreheightmax'};
          delete $glyphhashref->{'scoreheightmin'};
	  push @newth,$newth;
	}
      }
    }
    push @{$ch->{'type'}},@newth;
    @newth =();
    #repeat process for colour i.e. for all glyphs with scorecolormax and scorecolormin defined create new types with the same glyph but darker
    for my $th (@{$ch->{'type'}}){
      my ($scorecolormax, $scorecolormin, $bgcolor, $fgcolor) =map{[(values %{$th->{'glyph'}->[0]})]->[0]->[0]->{$_}} qw(scorecolormax scorecolormin bgcolor fgcolor);
      if(defined($scorecolormax) and defined($scorecolormin) and (defined($fgcolor) or defined($bgcolor))){
	for my $h (1 .. $ncolors){
	  my $newth =dclone($th);
	  $newth->{'type_id'}.="_$h";
	  my $glyphhashref = [(values %{$newth->{'glyph'}->[0]})]->[0]->[0];
          $glyphhashref->{'fgcolor'}=_colordivider($h,$ncolors,$fgcolor) if defined($fgcolor);
	  $glyphhashref->{'bgcolor'}=_colordivider($h,$ncolors,$bgcolor) if defined($bgcolor);
          delete $glyphhashref->{'scorecolormax'};
          delete $glyphhashref->{'scorecolormin'};
	  push @newth,$newth;
	}
      }
    }
    push @{$ch->{'type'}},@newth;
  }
  my $return = qq(<?xml version="1.0" standalone="yes"?>
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
);
  $return.= _po($stylesheethash,"stylesheet");
  $return.=qq(</DASSTYLE>\n);
  return $return;
}
#recursive function to build up XML from DasLite's stylesheet data structure...(probably easier to rewrite than to understand),
sub _po{my($c,$t)=@_;my $s=""; if(ref($c)eq"HASH"){if($t){my %nh=%{$c};$s.= "<".uc($t).(exists(${$c}{$t."_id"})?" id=\"".delete($nh{$t."_id"})."\"":(exists(${$c}{$t."_version"})?" version=\"".delete($nh{$t."_version"})."\"":"")).">\n". _po(\%nh). "</".uc($t).">\n"}else{while (my($k,$v)=each %{$c}){$s.= "<".uc($k).">" unless ref($v)eq"ARRAY"; $s.= "\n" if ref($v)eq"HASH"; $s.=_po($v,$k); $s.= "</".uc($k).">\n" unless ref($v)eq"ARRAY"}}return $s}elsif(ref($c)eq"ARRAY"){for(@{$c}){$s.=_po($_,$t)}}else{$s.= $c} return $s}
sub _colordivider{
  my ($h,$ncolors,$col)=@_; # should change to @cols and map though color space....
  if (my @hexcols= $col=~/^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i){
    return join "", map {sprintf("%02x",int($h*hex($_)/$ncolors))} @hexcols;
  }
  return $col;
}

sub build_features {
  my ($self, $opts) = @_;
  my $ncolors =  defined(${$self->config}{'ncolors'})?$self->config->{'ncolors'}:5;
  my $seg     = $opts->{'segment'};
  my $start   = $opts->{'start'};
  my $end     = $opts->{'end'};

  my $das = Bio::DasLite->new({
			       'dsn' => $self->config->{'sourcedsn'},
			      });
  my %sh=();
  #there now follows some horrific mining of the stylesheet data structure to obtain min and max scores to be used for type and category
  for my $ch (@{[values %{$das->stylesheet()}]->[0]->[0]->{'category'}}) {my $cat =$ch->{'category_id'}; for my $th (@{$ch->{'type'}}){ for my $mmt (qw(scoreheightmax scoreheightmin height scorecolormax scorecolormin bgcolor fgcolor)){ $sh{$cat}{$th->{'type_id'}}{$mmt}=([(values %{$th->{'glyph'}->[0]})]->[0]->[0]->{$mmt} )} }}

#warn Dumper \%sh;
#while(my ($c, $ch)=each %sh) {while(my ($t, $th)=each %{$ch}){while(my ($k, $v)=each %{$th}) {warn "$c $t $k \n"} warn "defined=".(map {defined($sh{$c}{$t}{$_})} qw(scoreheightmax scoreheightmin height))."\n"}}

  my @results=();
  $das->features((exists(${$opts}{'start'})?"$seg:$start,$end":"$seg"), sub{my $fr=shift; push @results,$fr if $fr->{feature_id}});
  for my $f (@results){#note the keywords for stylesheet and feature data structures differ...,
    my ($scoreheightmax, $scoreheightmin, $height) =map{$sh{$f->{'type_category'}}{$f->{'type'}}{$_}} qw(scoreheightmax scoreheightmin height);
#warn Dumper [$scoreheightmax, $scoreheightmin, $height];
    my ($scorecolormax, $scorecolormin, $bgcolor, $fgcolor) =map{$sh{$f->{'type_category'}}{$f->{'type'}}{$_}} qw(scorecolormax scorecolormin bgcolor fgcolor);
    if(defined($scoreheightmax) and defined($scoreheightmin) and defined($height)){
      my $h=($f->{'score'} - $scoreheightmin)/($scoreheightmax - $scoreheightmin);
      $h=int($h*($height-1));
      $h=0 if $h<0;
      $h+=1;
      $h=$height if $h > $height;
      $f->{'type'}.="_$h";
    }
#warn Dumper [$scorecolormax, $scorecolormin, $bgcolor, $fgcolor];
    if(defined($scorecolormax) and defined($scorecolormin) and (defined($fgcolor) or defined($bgcolor))){
      my $h=($f->{'score'} - $scorecolormin)/($scorecolormax - $scorecolormin);
      $h=int($h*($ncolors));
      $h=0 if $h<0;
      $h+=1;
      $h=$ncolors if $h > $ncolors;
      $f->{'type'}.="_$h";
    }
  }
  return @results;
}

1;
