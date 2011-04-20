#
# Ensembl module for Bio::EnsEMBL::Funcgen::DBSQL::BindingMatrixAdaptor
#
# You may distribute this module under the same terms as Perl itself

=head1 NAME

Bio::EnsEMBL::Funcgen::DBSQL::BindingMatrixAdaptor - A database adaptor for fetching and
storing Funcgen BindingMatrix objects.

=head1 SYNOPSIS

my $matrix_adaptor = $db->get_BindingMatrixAdaptor();
my $matrix = $matrix_adaptor->fetch_by_name("MA0122.1");

=head1 DESCRIPTION

The BindingMatrixAdaptor is a database adaptor for storing and retrieving
Funcgen Matrix objects.


=head1 SEE ALSO

Bio::EnsEMBL::Funcgen::BindingMatrix


=head1 LICENSE

  Copyright (c) 1999-2009 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <ensembl-dev@ebi.ac.uk>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.


=cut


use strict;
use warnings;

package Bio::EnsEMBL::Funcgen::DBSQL::BindingMatrixAdaptor;

use Bio::EnsEMBL::Utils::Exception qw( warning throw );
use Bio::EnsEMBL::Funcgen::BindingMatrix;
use Bio::EnsEMBL::Funcgen::DBSQL::BaseAdaptor;

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Funcgen::DBSQL::BaseAdaptor);

#Exported from BaseAdaptor
$true_tables{binding_matrix} = [['binding_matrix', 'bm']];
#deref to avoid modifying the true tables
@{$tables{binding_matrix}} = @{$true_tables{binding_matrix}};

=head2 fetch_all_by_name

  Arg [1]    : string - name of Matrix
  Arg [2]    : string - (optional) type of Matrix (e.g. 'Jaspar')
  Example    : my $matrix = $matrix_adaptor->fetch_all_by_name('MA0122.1');
  Description: Fetches matrix objects given a name and an optional type.
               If both are specified, only one unique BindingMatrix will be returned
  Returntype : Arrayref of Bio::EnsEMBL::Funcgen::BindingMatrix objects
  Exceptions : Throws if no name if defined
  Caller     : General
  Status     : At risk - Change this to fetch_all_by_name_FeatureType

=cut

sub fetch_all_by_name{
  my ($self, $name, $type) = @_;

  throw("Must specify a BindingMatrix name") if(! $name);

  my $constraint = " bm.name = ? ";
  $constraint .= " AND bm.type = ?" if $type;
  
  $self->bind_param_generic_fetch($name,         SQL_VARCHAR);
  $self->bind_param_generic_fetch($type,         SQL_VARCHAR) if $type;

  return $self->generic_fetch($constraint);
}

=head2 fetch_all_by_name_FeatureType

  Arg [1]    : string - name of Matrix
  Arg [2]    : Bio::EnsEMBL::Funcgen::FeatureType
  Arg [3]    : string - (optional) type of Matrix (e.g. 'Jaspar')
  Description: Fetches matrix objects given a name and an optional type.
               If both are specified, only one unique BindingMatrix will be returned
  Returntype : Arrayref of Bio::EnsEMBL::Funcgen::BindingMatrix objects
  Exceptions : Throws if no name if defined
  Caller     : General
  Status     : At risk

=cut

sub fetch_all_by_name_FeatureType{
  my ($self, $name, $ftype, $type) = @_;

  throw("Must specify a BindingMatrix name") if(! $name);
  #$self->db->is_stored_and_valid('Bio::EnsEMBL::Funcgen::FeatureType', $ftype);

  my $constraint = " bm.name = ? and bm.feature_type_id = ?";
  $constraint .= " AND bm.type = ?" if $type;
  
  $self->bind_param_generic_fetch($name,         SQL_VARCHAR);
  $self->bind_param_generic_fetch($ftype->dbID,  SQL_INTEGER);
  $self->bind_param_generic_fetch($type,         SQL_VARCHAR) if $type;

  return $self->generic_fetch($constraint);
}


=head2 fetch_all_by_FeatureType

  Arg [1]    : Bio::EnsEMBL::Funcgen::FeatureType
  Arg [2]    : string - (optional) type of Matrix (e.g. 'Jaspar')
  Example    : my $matrix = $matrix_adaptor->fetch_by_FeatureType($ftype);
  Description: Fetches BindingMatrix objects given it's FeatureType
  Returntype : Bio::EnsEMBL::Funcgen::BindingMatrix
  Exceptions : Throws if FeatureType is not valid
  Caller     : General
  Status     : At risk

=cut

sub fetch_all_by_FeatureType{
  my ($self, $ftype, $type) = @_;

  $self->db->is_stored_and_valid('Bio::EnsEMBL::Funcgen::FeatureType', $ftype);

  my $constraint = " bm.feature_type_id = ?";
  $constraint .= " AND bm.type = ?" if $type;

  $self->bind_param_generic_fetch($ftype->dbID,  SQL_INTEGER);
  $self->bind_param_generic_fetch($type,  SQL_VARCHAR) if $type;

  return $self->generic_fetch($constraint);
}





=head2 _tables

  Args       : None
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Returns the names and aliases of the tables to use for queries.
  Returntype : List of listrefs of strings
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _tables {
  my $self = shift;
	
  return @{$tables{binding_matrix}};
}

=head2 _columns

  Args       : None
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Returns a list of columns to use for queries.
  Returntype : List of strings
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _columns {
  my $self = shift;
	
  return qw( bm.binding_matrix_id bm.name bm.type bm.frequencies bm.description bm.feature_type_id);
}

=head2 _objs_from_sth

  Arg [1]    : DBI statement handle object
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Creates objects from an executed DBI statement handle.
  Returntype : Arrayref of Bio::EnsEMBL::Funcgen::BindingMatrix objects
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _objs_from_sth {
	my ($self, $sth) = @_;
	
	my (@result, $matrix_id, $name, $type, $freq, $desc, $ftype_id);
	
	$sth->bind_columns(\$matrix_id, \$name, \$type, \$freq, \$desc, \$ftype_id);
	
	my $ftype_adaptor = $self->db->get_FeatureTypeAdaptor;
	my %ftype_cache;

	while ( $sth->fetch() ) {

	  if(! exists $ftype_cache{$ftype_id}){
		$ftype_cache{$ftype_id} = $ftype_adaptor->fetch_by_dbID($ftype_id);
	  }


	  my $matrix = Bio::EnsEMBL::Funcgen::BindingMatrix->new
		(
		 -dbID         => $matrix_id,
		 -NAME         => $name,
		 -TYPE         => $type,
		 -FREQUENCIES  => $freq,
		 -DESCRIPTION  => $desc,
		 -FEATURE_TYPE => $ftype_cache{$ftype_id},
		 -ADAPTOR      => $self,
		);
	  
	  push @result, $matrix;
	  
	}

	return \@result;
}



=head2 store

  Args       : List of Bio::EnsEMBL::Funcgen::BindingMatrix objects
  Example    : $matrix_adaptor->store($m1, $m2, $m3);
  Description: Stores given Matrix objects in the database. 
			   Sets dbID and adaptor on the objects that it stores.
  Returntype : None
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut

sub store {
  my $self = shift;
  my @args = @_;
  
  
  my $sth = $self->prepare("
			INSERT INTO binding_matrix
			(name, type, frequencies, description, feature_type_id)
			VALUES (?, ?, ?, ?, ?)");
    
  my $s_matrix;
  
  foreach my $matrix (@args) {

    if ( ! $matrix->isa('Bio::EnsEMBL::Funcgen::BindingMatrix') ) {
      throw('Can only store BindingMatrix objects, skipping $matrix');
    }

	$self->db->is_stored_and_valid('Bio::EnsEMBL::Funcgen::FeatureType', $matrix->feature_type);


    
    if (!( $matrix->dbID() && $matrix->adaptor() == $self )){
      
      #Check for previously stored BindingMatrix
      ($s_matrix) = @{$self->fetch_all_by_name_FeatureType($matrix->name(), $matrix->feature_type, $matrix->type())};
	
      if(! $s_matrix){
      	
		$sth->bind_param(1, $matrix->name(),               SQL_VARCHAR);
		$sth->bind_param(2, $matrix->type(),               SQL_VARCHAR);
		$sth->bind_param(3, $matrix->frequencies(),        SQL_LONGVARCHAR);
		$sth->bind_param(4, $matrix->description(),        SQL_VARCHAR);
		$sth->bind_param(5, $matrix->feature_type->dbID(), SQL_INTEGER);
				
		$sth->execute();
		my $dbID = $sth->{'mysql_insertid'};
		$matrix->dbID($dbID);
		$matrix->adaptor($self);

		$self->store_associated_feature_types($matrix);
	  }
      else{
		$matrix = $s_matrix;
		warn("Using previously stored Matrix:\t".$matrix->name()."\n");
		
		#Could update associated FeatureTypes here
      }
    }
  }

  return \@args;
}


=head2 list_dbIDs

  Args       : None
  Example    : my @amtrix_ids = @{$matrix_adaptor->list_dbIDs()};
  Description: Gets an array of internal IDs for all Matrix objects in the current database.
  Returntype : List of ints
  Exceptions : None
  Caller     : ?
  Status     : At risk

=cut

sub list_dbIDs {
    my ($self) = @_;
	
    return $self->_list_dbIDs('binding_matrix');
}



1;