# Ensembl module for Bio::EnsEMBL::Variation::AlleleFeature
#
# Copyright (c) 2005 Ensembl
#


=head1 NAME

Bio::EnsEMBL::Variation::AlleleFeature - A genomic position for an allele in a sample.

=head1 SYNOPSIS

    # Allele feature representing a single nucleotide polymorphism
    $af = Bio::EnsEMBL::Variation::AlleleFeature->new
       (-start   => 100,
        -end     => 100,
        -strand  => 1,
        -slice   => $slice,
        -allele_string => 'A',
        -variation_name => 'rs635421',
        -variation => $v);
    ...

    # a allele feature is like any other ensembl feature, can be
    # transformed etc.
    $af = $af->transform('supercontig');

    print $af->start(), "-", $af->end(), '(', $af->strand(), ')', "\n";

    print $af->name(), ":", $af->allele_string();

    # Get the Variation object which this feature represents the genomic
    # position of. If not already retrieved from the DB, this will be
    # transparently lazy-loaded
    my $v = $af->variation();

=head1 DESCRIPTION

This is a class representing the genomic position of a allele in a sample
from the ensembl-variation database.  The actual variation information is
represented by an associated Bio::EnsEMBL::Variation::Variation object. Some
of the information has been denormalized and is available on the feature for
speed purposes.  A AlleleFeature behaves as any other Ensembl feature.
See B<Bio::EnsEMBL::Feature> and B<Bio::EnsEMBL::Variation::Variation>.

=head1 CONTACT

Post questions to the Ensembl development list: ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;

package Bio::EnsEMBL::Variation::AlleleFeature;

use Bio::EnsEMBL::Feature;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Variation::Utils::Sequence qw(unambiguity_code);
use Bio::EnsEMBL::Variation::ConsequenceType;

my %CONSEQUENCE_TYPES = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_TYPES;


our @ISA = ('Bio::EnsEMBL::Feature');

=head2 new

  Arg [-ADAPTOR] :
    see superclass constructor

  Arg [-START] :
    see superclass constructor
  Arg [-END] :
    see superclass constructor

  Arg [-STRAND] :
    see superclass constructor

  Arg [-SLICE] :
    see superclass constructor

  Arg [-VARIATION_NAME] :
    string - the name of the variation this feature is for (denormalisation
    from Variation object).

 Arg [-SOURCE] :
    string - the name of the source where the SNP comes from

  Arg [-VARIATION] :
    int - the variation object associated with this feature.

  Arg [-VARIATION_ID] :
    int - the internal id of the variation object associated with this
    identifier. This may be provided instead of a variation object so that
    the variation may be lazy-loaded from the database on demand.
    
  Arg [-SAMPLE_ID] :
    int - the internal id of the sample object associated with this
    identifier. This may be provided instead of the object so that
    the population/individual may be lazy-loaded from the database on demand.

  Arg [-ALLELE_STRING] :
    string - the allele for this AlleleFeature object.
  
  Arg [-CONSEQUENCE_TYPE] :
	string - the consequence type of this AlleleFeature object.

  Example    :
    $af = Bio::EnsEMBL::Variation::AlleleFeature->new
       (-start   => 100,
        -end     => 100,
        -strand  => 1,
        -slice   => $slice,
        -allele_string => 'A',
		-consequence_type => 'NON_SYNONYMOUS_CODING',
        -variation_name => 'rs635421',
	-source => 'Celera',
	-sample_id  => $sample_id,
        -variation => $v);

  Description: Constructor. Instantiates a new AlleleFeature object.
  Returntype : Bio::EnsEMBL::Variation::AlleleFeature
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;

  my $self = $class->SUPER::new(@_);
  my ($allele, $cons, $var_name, $variation, $variation_id,$population, $sample_id, $source) =
    rearrange([qw(ALLELE_STRING CONSEQUENCE_TYPE VARIATION_NAME 
                  VARIATION VARIATION_ID SAMPLE_ID SOURCE)], @_);

  $self->{'allele_string'}    = $allele;
  $self->{'consequence_type'} = $cons;
  $self->{'variation_name'}   = $var_name;
  $self->{'variation'}        = $variation;
  $self->{'_variation_id'}    = $variation_id;
  $self->{'_sample_id'}       = $sample_id;
  $self->{'source'}           = $source;

  return $self;
}



sub new_fast {
  my $class = shift;
  my $hashref = shift;
  return bless $hashref, $class;
}


=head2 allele_string

  Arg [1]    : string $newval (optional)
               The new value to set the allele attribute to
  Example    : $allele = $obj->allele_string()
  Description: Getter/Setter for the allele attribute.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

sub allele_string{
  my $self = shift;
  return $self->{'allele_string'} = shift if(@_);
  
  return $self->{'allele_string'} if ($self->{'_half_genotype'}); #for half genotypes
  return join('|',split (//,unambiguity_code($self->{'allele_string'}))); #for heterozygous alleles
}


=head2 consequence_type

  Arg [1]    : string $newval (optional)
               The new value to set the consequence_type attribute to
  Example    : $con = $obj->consequence_type()
  Description: Getter/Setter for the consequence_type attribute.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

sub consequence_type{
  my $self = shift;
  my $con = shift;
  
  if(defined($con)) {
	if($CONSEQUENCE_TYPES{$con}){
	  $self->{'consequence_type'} = $con;
    }
	
	else {
	  warning("You are trying to set the consequence type to a non-allowed type. The allowed types are: ".(join ", ", keys %CONSEQUENCE_TYPES));
	}
  }
  
  return $self->{'consequence_type'};
}



=head2 display_consequence

  Args	     : None
  Example    : $con = $obj->display_consequence()
  Description: Getter for the consequence_type attribute. Simply an alias for
			   $obj->consequence_type()
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

sub display_consequence{
  my $self = shift;
  return $self->consequence_type();
}


=head2 variation_name

  Arg [1]    : string $newval (optional)
               The new value to set the variation_name attribute to
  Example    : $variation_name = $obj->variation_name()
  Description: Getter/Setter for the variation_name attribute.  This is the
               name of the variation associated with this feature.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

sub variation_name{
  my $self = shift;
  return $self->{'variation_name'} = shift if(@_);
  return $self->{'variation_name'};
}

=head2 variation

  Arg [1]    : (optional) Bio::EnsEMBL::Variation::Variation $variation
  Example    : $v = $af->variation();
  Description: Getter/Setter for the variation associated with this feature.
               If not set, and this AlleleFeature has an associated adaptor
               an attempt will be made to lazy-load the variation from the
               database.
  Returntype : Bio::EnsEMBL::Variation::Variation
  Exceptions : throw on incorrect argument
  Caller     : general
  Status     : At Risk

=cut

sub variation {
  my $self = shift;

  if(@_) {
    if(!ref($_[0]) || !$_[0]->isa('Bio::EnsEMBL::Variation::Variation')) {
      throw("Bio::EnsEMBL::Variation::Variation argument expected");
    }
    $self->{'variation'} = shift;
  }
  elsif(!defined($self->{'variation'}) && $self->{'adaptor'} &&
        defined($self->{'_variation_id'})) {
    # lazy-load from database on demand
    my $va = $self->{'adaptor'}->db()->get_VariationAdaptor();
    $self->{'variation'} = $va->fetch_by_dbID($self->{'_variation_id'});
  }

  return $self->{'variation'};
}

=head2 variation_feature

  Arg [1]    : (optional) Bio::EnsEMBL::Variation::VariationFeature $vf
  Example    : $vf = $af->variation_feature();
  Description: Getter/Setter for the variation feature associated with this feature.
               If not set, and this AlleleFeature has an associated adaptor
               an attempt will be made to lazy-load the variation from the
               database.
  Returntype : Bio::EnsEMBL::Variation::VariationFeature
  Exceptions : throw on incorrect argument
  Caller     : general
  Status     : At Risk

=cut

sub variation_feature {
  my $self = shift;

  if(@_) {
    if(!ref($_[0]) || !$_[0]->isa('Bio::EnsEMBL::Variation::VariationFeature')) {
      throw("Bio::EnsEMBL::Variation::VariationFeature argument expected");
    }
    $self->{'variation_feature'} = shift;
  }
  elsif(!defined($self->{'variation_feature'}) && $self->{'adaptor'} &&
        defined($self->{'_variation_feature_id'})) {
    # lazy-load from database on demand
    my $va = $self->{'adaptor'}->db()->get_VariationFeatureAdaptor();
    $self->{'variation_feature'} = $va->fetch_by_dbID($self->{'_variation_feature_id'});
  }

  return $self->{'variation_feature'};
}

=head2 individual

  Arg [1]    : (optional) Bio::EnsEMBL::Variation::Individual $individual
  Example    : $p = $af->individual();
  Description: Getter/Setter for the individual associated with this feature.
               If not set, and this AlleleFeature has an associated adaptor
               an attempt will be made to lazy-load the individual from the
               database.
  Returntype : Bio::EnsEMBL::Variation::Individual
  Exceptions : throw on incorrect argument
  Caller     : general
  Status     : At Risk

=cut

sub individual {
  my $self = shift;

  if(@_) {
    if(!ref($_[0]) || !$_[0]->isa('Bio::EnsEMBL::Variation::Individual')) {
      throw("Bio::EnsEMBL::Variation::Individual argument expected");
    }
    $self->{'individual'} = shift;
  }
  elsif(!defined($self->{'individual'}) && $self->{'adaptor'} &&
        defined($self->{'_sample_id'})) {
    # lazy-load from database on demand
    my $ia = $self->{'adaptor'}->db()->get_IndividualAdaptor();
    $self->{'individual'} = $ia->fetch_by_dbID($self->{'_sample_id'});
    if (!defined $self->{'individual'}){
	warning("AlleleFeature attached to Strain, not Individual");
    }
  }

  return $self->{'individual'};
}


=head2 apply_edit
    
    Arg [1]    : reference to string $seqref
    Arg [2]    : int $start of the seq_ref
    Example    : $sequence = 'ACTGAATATTTAAGGCA';
               $af->apply_edit(\$sequence,$start);
               print $sequence, "\n";
    Description: Applies this AlleleFeature directly to a sequence which is
               passed by reference.  
               If either the start or end of this AlleleFeature are not defined
               this function will not do anything to the passed sequence.
    Returntype : reference to the same sequence that was passed in
    Exceptions : none
    Caller     : Slice
    Status     : At Risk

=cut

sub apply_edit  {

  my $self   = shift;
  my $seqref = shift;

  if(ref($seqref) ne 'SCALAR') {
    throw("Reference to scalar argument expected");
  }

  if(!defined($self->{'start'}) || !defined($self->{'end'})) {
    return $seqref;
  }


  my $len = $self->length;
  substr($$seqref, $self->{'start'}-1, $len) = $self->{'allele_string'} if ($self->{'allele_string'} ne '-'); 
  substr($$seqref, $self->{'start'}-1, 0) = $self->{'allele_string'} if ($self->{'allele_string'} eq '-');
  return $seqref;

}

=head2 length_diff

  Arg [1]    : none
  Example    : my $diff = $af->length_diff();
  Description: Returns the difference in length caused by applying this
               AlleleFeature to a sequence.  This may be be negative (deletion),
               positive (insertion) or 0 (replacement).
               If either start or end are not defined 0 is returned.
  Returntype : int
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

sub length_diff  {

  my $self = shift;

  return 0 if(!defined($self->{'end'}) || !defined($self->{'start'}));

  return length($self->{'allele_string'}) - ($self->{'end'} - $self->{'start'} + 1) if ($self->{'allele_string'} ne '-'); 
  return 0 - ($self->{'end'} - $self->{'start'} +1) if ($self->{'allele_string'} eq '-'); #do we need the +1 in the distance ??

}

sub length {
  my $self = shift;
  return $self->{'end'} - $self->{'start'} + 1;
}

=head2 source

  Arg [1]    : string $source (optional)
               The new value to set the source attribute to
  Example    : $source = $vf->source()
  Description: Getter/Setter for the source attribute
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

sub source{
  my $self = shift;
  return $self->{'source'} = shift if(@_);
  return $self->{'source'};
}

=head2 ref_allele_string

  Args       : None
  Example    : $allele = $obj->ref_allele_string()
  Description: Getter for the reference allele.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

 sub ref_allele_string{
   my $self = shift;

   my $reference_allele;
   if ( ref ($self->slice) eq 'Bio::EnsEMBL::Slice' ){
       #we already have the reference slice, so just get the sequence
       $reference_allele = $self->seq;
   }
   else{
       #we have a Strain or IndividualSlice, get the reference sequence from the method
       $reference_allele = $self->slice->ref_subseq($self->start,$self->end,$self->strand);
   }

   return $reference_allele;
 }

=head2 get_all_sources

    Args        : none
    Example     : my @sources = @{$af->get_all_sources()};
    Description : returns a list of all the sources for this
                  AlleleFeature
    ReturnType  : reference to list of strings
    Exceptions  : none
    Caller      : general
    Status      : At Risk
                : Variation database is under development.
=cut

sub get_all_sources{
    my $self = shift;
    
    my @sources;
    my %sources;
    if ($self->{'adaptor'}){
	map {$sources{$_}++} @{$self->{'adaptor'}->get_all_synonym_sources($self)};
	$sources{$self->source}++;
	@sources = keys %sources;
	return \@sources;	
    }
    return \@sources;
}
1;
