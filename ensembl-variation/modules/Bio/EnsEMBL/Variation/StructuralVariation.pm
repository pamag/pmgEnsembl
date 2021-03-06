# Ensembl module for Bio::EnsEMBL::Variation::StructuralVariation
#
# Copyright (c) 2004 Ensembl
#


=head1 NAME

Bio::EnsEMBL::Variation::StructuralVariation - A genomic position for a structural variation.

=head1 SYNOPSIS

    # Structural variation feature representing a CNV
    $svf = Bio::EnsEMBL::Variation::StructuralVariation->new
       (-start   => 100,
        -end     => 200,
        -strand  => 1,
        -slice   => $slice,
        -variation_name => 'esv25480',
		-class     => 'CNV');

    ...

    # a variation feature is like any other ensembl feature, can be
    # transformed etc.
    $svf = $svf->transform('supercontig');

    print $svf->start(), "-", $svf->end(), '(', $svf->strand(), ')', "\n";

    print $svf->name(), ":", $svf->class();

=head1 DESCRIPTION

This is a class representing the genomic position of a structural variation
from the ensembl-variation database.  A StructuralVariation behaves as any other
Ensembl feature. See B<Bio::EnsEMBL::Feature> and
B<Bio::EnsEMBL::Variation::Variation>.

=head1 CONTACT

Post questions to the Ensembl development list: ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;

package Bio::EnsEMBL::Variation::StructuralVariation;

use Bio::EnsEMBL::Feature;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Variation::Variation;
use Bio::EnsEMBL::Slice;

our @ISA = ('Bio::EnsEMBL::Feature');

=head2 new

  Arg [-dbID] :
    see superclass constructor

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
	
  Arg [-BOUND_START] :
	int - the 5'-most coordinate of the underlying structural variation
	
  Arg [-BOUND_END] :
	int - the 3'-most coordinate of the underlying structural variation

  Arg [-VARIATION_NAME] :
    string - the name of the variation this feature is for (denormalisation
    from Variation object).

  Arg [-SOURCE] :
    string - the name of the source where the variation comes from
	
  Arg [-SOURCE_DESCRIPTION] :
	string - description of the source

  Arg [-TYPE] :
     string - the class of structural variation e.g. 'CNV'

  Arg [-VARIATION_ID] :
    int - the internal id of the variation object associated with this
    identifier. This may be provided instead of a variation object so that
    the variation may be lazy-loaded from the database on demand.

  Example    :
    $svf = Bio::EnsEMBL::Variation::StructuralVariation->new
       (-start   => 100,
        -end     => 200,
        -strand  => 1,
        -slice   => $slice,
        -variation_name => 'esv25480',
		-class => 'CNV');

  Description: Constructor. Instantiates a new StructuralVariation object.
  Returntype : Bio::EnsEMBL::Variation::StructuralVariation
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;

  my $self = $class->SUPER::new(@_);
  my ($var_name, $source, $source_description, $sv_class, $bound_start, $bound_end) =
    rearrange([qw(VARIATION_NAME SOURCE SOURCE_DESCRIPTION TYPE BOUND_START BOUND_END)], @_);

  $self->{'variation_name'}   = $var_name;
  $self->{'source'}           = $source;
  $self->{'source_description'}           = $source_description;
  $self->{'class'}  = $sv_class;
  $self->{'bound_start'} = $bound_start;
  $self->{'bound_end'} = $bound_end;
 
  return $self;
}



sub new_fast {
  my $class = shift;
  my $hashref = shift;
  return bless $hashref, $class;
}


=head2 display_id

  Arg [1]    : none
  Example    : print $svf->display_id(), "\n";
  Description: Returns the 'display' identifier for this feature. For
               StructuralVariations this is simply the name of the variation
               it is associated with.
  Returntype : string
  Exceptions : none
  Caller     : webcode
  Status     : At Risk

=cut

sub display_id {
  my $self = shift;
  return $self->{'variation_name'} || '';
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
  Status     : Stable

=cut

sub variation_name{
  my $self = shift;
  return $self->{'variation_name'} = shift if(@_);
  return $self->{'variation_name'};
}


=head2 get_nearest_Gene

  Example     : $svf->get_nearest_Gene($flanking_size);
  Description : Getter a Gene which is associated to or nearest to the StructuralVariation
  Returntype  : a reference to a list of objects of Bio::EnsEMBL::Gene
  Exceptions  : None
  Caller      : general
  Status      : At Risk

=cut

sub get_nearest_Gene{

    my $self = shift;
    my $flanking_size = shift; #flanking size is optional
    $flanking_size ||= 0;
    my $sa = $self->{'adaptor'}->db()->dnadb->get_SliceAdaptor();
    my $slice = $sa->fetch_by_Feature($self,$flanking_size);
    my @genes = @{$slice->get_all_Genes};
    return \@genes if @genes; #$svf is on the gene

    if (! @genes) { #if $svf is not on the gene, increase flanking size
      warning("flanking_size $flanking_size is not big enough to overlap a gene, increase it by 1,000,000");
      $flanking_size += 1000000;
      $slice = $sa->fetch_by_Feature($self,$flanking_size);
      @genes = @{$slice->get_all_Genes};
    }
    if (@genes) {
      my %distances = ();
      foreach my $g (@genes) {
        if ($g->seq_region_start > $self->start) {
          $distances{$g->seq_region_start-$self->start}=$g;
        }
        else {
          $distances{$self->start-$g->seq_region_end}=$g;
        }
      }
      my @distances = sort {$a<=>$b} keys %distances;
      my $shortest_distance = $distances[0];
      if ($shortest_distance) {
        my $nearest_gene = $distances{$shortest_distance};
        return [$nearest_gene];
      }
    }
    else {
      throw("variation_feature with flanking_size $flanking_size is not overlap with a gene, try a bigger flanking_size");
    }
}


=head2 class

    Args         : None
    Example      : my $sv_class = $svf->class()
    Description  : Getter/setter for the class of structural variation
    ReturnType   : String $sv_class
    Exceptions   : none
    Caller       : General
    Status       : At Risk

=cut

sub class{
  my $self = shift;
  
  $self->{'class'} = shift if @_;
  
  return $self->{'class'};
}



=head2 source

  Arg [1]    : string $source (optional)
               The new value to set the source attribute to
  Example    : $source = $svf->source()
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



=head2 source_description

  Arg [1]    : string $source_description (optional)
               The new value to set the source_description attribute to
  Example    : $source_description = $svf->source_description()
  Description: Getter/Setter for the source_description attribute
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : At Risk

=cut

sub source_description{
  my $self = shift;
  return $self->{'source_description'} = shift if(@_);
  return $self->{'source_description'};
}


=head2 bound_start

	Arg [1]    : int $bound_start (optional)
				The new value to set the bound_start attribute to
    Example     : my $bound_start = $svf->bound_start();
    Description : Getter/setter for the 5'-most coordinate defined for this StructuralVariation
    ReturnType  : int
    Exceptions  : none
    Caller      : general
    Status      : At Risk
=cut

sub bound_start{
  my $self = shift;
  return $self->{'bound_start'} = shift if(@_);
  return $self->{'bound_start'};
}


=head2 bound_end

	Arg [1]    : int $bound_end (optional)
				The new value to set the bound_end attribute to
    Example     : my $bound_end = $svf->bound_end();
    Description : Getter/setter for the 3'-most coordinate defined for this StructuralVariation
    ReturnType  : int
    Exceptions  : none
    Caller      : general
    Status      : At Risk
=cut

sub bound_end{
  my $self = shift;
  return $self->{'bound_end'} = shift if(@_);
  return $self->{'bound_end'};
}

=head2 get_reference_sequence

    Args        : none
    Example     : my $seq = $svf->get_reference_sequence
    Description : returns a string containing the reference sequence for the region
				  covered by this StructuralVariation
    ReturnType  : string
    Exceptions  : none
    Caller      : general
    Status      : At Risk
=cut

sub get_reference_sequence{
  my $self = shift;
  
  return $self->feature_Slice->seq();
}


sub transform {
  my $self = shift;
  
  # run the transform method from the parent class
  my $transformed = $self->SUPER::transform(@_);
  
  if(defined $transformed) {
	
	# fit the bound_start and bound_end coords to the new coords
	$transformed->_fix_bounds($self);
  }
  
  return $transformed;
}


sub transfer {
  my $self = shift;
  
  # run the transfer method from the parent class
  my $transferred = $self->SUPER::transfer(@_);
  
  if(defined $transferred) {
	
	# fit the bound_start and bound_end coords to the new coords
	$transferred->_fix_bounds($self);
  }
  
  return $transferred;
}



sub _fix_bounds {
  my $self = shift;
  my $old = shift;
  
  if(defined $old->{'bound_start'}) {
	$self->{'bound_start'} = $self->start - ($old->start - $old->{'bound_start'});
  }
  
  if(defined $old->{'bound_end'}) {
	$self->{'bound_end'} = $self->end + ($old->{'bound_end'} - $old->end);
  }
}

1;
