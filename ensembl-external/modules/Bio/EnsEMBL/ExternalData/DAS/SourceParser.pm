=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::SourceParser

=head1 SYNOPSIS

  my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
    -timeout  => 5,
    -proxy    => 'http://proxy.company.com',
  );
  
  my $sources = $parser->fetch_Sources(
    -location => 'http://www.dasregistry.org/das',
    -species  => 'Homo_sapiens'
  );
  for my $source (@{ $sources }) {
    printf "URL: %s, Description: %s, Coords: %s\n",
            $source->full_url,
            $source->description,
            join '; ', @{ $source->coord_systems };
  }

=head1 DESCRIPTION

Parses XML produced by the 'sources' DAS command, creating object
representations of each source.

=head1 AUTHOR

Andy Jenkinson <aj@ebi.ac.uk>

=cut
package Bio::EnsEMBL::ExternalData::DAS::SourceParser;

use strict;
use warnings;
use vars qw(@EXPORT_OK);
use base qw(Exporter);
@EXPORT_OK = qw(%SNP_COORDS @SNP_COORDS %GENE_COORDS @GENE_COORDS %PROT_COORDS @PROT_COORDS is_genomic %AUTHORITY_MAPPINGS %TYPE_MAPPINGS %COORD_MAPPINGS %NON_GENOMIC_COORDS);

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::ExternalData::DAS::CoordSystem;
use Bio::EnsEMBL::ExternalData::DAS::Source;
use Bio::Das::Lite;
use URI;

our $GENOMIC_REGEX = '^chromosome|clone|contig|scaffold|genescaffold|supercontig|ultracontig|reftig|group$';
our @GENE_COORDS = (
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ensembl_gene', -label => 'Ensembl Gene Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'entrezgene_acc', -label => 'Entrez Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'hgnc',    -species => 'Homo_sapiens', -label => 'HUGO Gene Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'mgi_acc', -species => 'Mus_musculus', -label => 'MGI Gene Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'mgi',     -species => 'Mus_musculus', -label => 'MGI Gene Symbol' ),
);
our @PROT_COORDS = (
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ensembl_peptide', -label => 'Ensembl Protein Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'uniprot_peptide', -label => 'UniProt Protein Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ipi_acc', -label => 'IPI Protein Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ipi_id',  -label => 'IPI Protein ID' ),
);
our @SNP_COORDS = (
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'dbsnp_rsid', -label => 'dbSNP Variation RS ID' ),
);

our %GENE_COORDS = map { $_->name => $_ } @GENE_COORDS;
our %PROT_COORDS = map { $_->name => $_ } @PROT_COORDS;
our %SNP_COORDS = map { $_->name => $_ } @SNP_COORDS;

# For compatibility with previous versions of Ensembl:
$PROT_COORDS{'uniprot/swissprot_acc'} = $PROT_COORDS{'uniprot_peptide'};
$PROT_COORDS{'uniprot/sptrembl'}      = $PROT_COORDS{'uniprot_peptide'};

# Intended for occasions when assembly names don't match between DAS and Ensembl
# TODO: get these from a config file of some sort?

our %AUTHORITY_MAPPINGS = (
  'NCBI m' => 'NCBIM',
  'Btau'   => 'Btau_',
  'MMUL'   => 'MMUL_',
  'Meug'   => 'Meug_',
);

our %TYPE_MAPPINGS = (
  'Gene Scaffold' => 'genescaffold',
);

our %COORD_MAPPINGS = (
  'Chromosome' => {
                   'BROADS' => {
                                '1' => {
                                        'Gasterosteus aculeatus' => 'group:BROADS1:Gasterosteus_aculeatus',
                                       },
                               },
                  },
);

our %NON_GENOMIC_COORDS = (
  'Gene_ID'          => {
                         'Ensembl'    => $GENE_COORDS{'ensembl_gene'},
                         'HUGO_ID'    => $GENE_COORDS{'hgnc'},
                         'MGI'        => $GENE_COORDS{'mgi_acc'},
                         'MGI_Symbol' => $GENE_COORDS{'mgi'},
                         'Entrez'     => $GENE_COORDS{'entrezgene_acc'},
                        },
  'Protein Sequence' => {
                         'Ensembl'    => $PROT_COORDS{'ensembl_peptide'},
                         'UniProt'    => $PROT_COORDS{'uniprot_peptide'},
                         'IPI'        => $PROT_COORDS{'ipi_acc'},
                         'IPI_ID'     => $PROT_COORDS{'ipi_id'},
                        },
  'Variation'        => {
                         'dbSNP'      => $SNP_COORDS{'dbsnp_rsid'},
                        },
);

=head1 METHODS

=head2 new

  Arg [..]   : List of optional named arguments:
               -PROXY     - A URL to use as an HTTP proxy server
               -NOPROXY   - A list of domains/hosts not to use the proxy for
               -TIMEOUT   - Timeout in seconds (default is 10)
  Example    : my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
                 -proxy    => 'http://proxy.company.com',
                 -timeout  => 10,
               );
  Description: Constructor
  Returntype : Bio::EnsEMBL::ExternalData::DAS::SourceParser
  Exceptions : If no location is specified
  Caller     : general
  Status     : Stable
  
=cut
sub new {
  my $class = shift;
  my ($proxy, $no_proxy, $timeout)
    = rearrange(['PROXY','NOPROXY','TIMEOUT'], @_);
  
  $timeout ||= 10;
  my $das = Bio::Das::Lite->new();
  $das->user_agent('Ensembl');
  $das->timeout($timeout);
  
  $das->http_proxy($proxy);
  if ($no_proxy) {
    if ($das->can('no_proxy')) {
      $das->no_proxy($no_proxy);
    } else {
      warning("Installed version of Bio::Das::Lite does not support use of 'no_proxy'");
    }
  }
  
  my $self = {
    'daslite'  => $das,
    'proxy'    => $proxy,
    'noproxy'  => $no_proxy,
    'timeout'  => $timeout,
  };
  bless $self, $class;
  
  return $self;
}

=head2 fetch_Sources

  Arg [..]   : List of named arguments:
               -LOCATION   -  A URL from which to obtain a list of sources XML.
                             This is usually a DAS registry or server URL, but
                             could be a local path to a directory containing an
                             XML file named "sources?" or "dsn?"
               -SPECIES    - (optional) scalar or arrayref species name filter
               -NAME       - (optional) scalar or arrayref source name filter
               -LOGIC_NAME - (optional) scalar or arrayref logic_name filter
  Example:     $arr = $parser->fetch_Sources(
                 -location => 'http://www.dasregistry.org/das',
                 -species => 'Homo_sapiens',
                 -name    => ['asd', 'atd', 'astd'],
               );
  Example:     $arr = $parser->fetch_Sources(
                 -location => 'file:///registry', # parses "/registry/sources?"
               );
  Description: Fetches DAS Source objects. The first call to this method
               initiates lazy parsing of the XML, and the results are stored.
               The different filter types supplied to this method are treated as
               a logical AND. Several filters of the same type are logical OR.
  Returntype : Arrayref of Bio::EnsEMBL::ExternalData::DAS::Source objects,
               sorted by label.
  Exceptions : If there is an error contacting the DAS registry/server.
  Caller     : general
  Status     : Stable
  
=cut
sub fetch_Sources {
  my $self = shift;
  my ($server, $f_species, $f_name, $f_logic)
    = rearrange([ 'LOCATION', 'SPECIES', 'NAME', 'LOGIC_NAME' ], @_);
  
  $server || throw('No DAS server specified');
  ($server, my $f_id) = $self->parse_das_string( $server );
  
  # Actual parsing is lazy
  if (!defined $self->{'_sources'}{$server}) {
    $self->_parse_server( $server );
  }
  
  my @sources = values %{ $self->{'_sources'}{$server} || {} };
  
  my @f_species = !defined $f_species ? ()
                : ref $f_species ? @{ $f_species } : ( $f_species );
  my @f_name    = !defined $f_name ? ()
                : ref $f_name ? @{ $f_name } : ( $f_name );
  my @f_logic   = !defined $f_logic ? ()
                : ref $f_logic ? @{ $f_logic } : ( $f_logic );
  
  # optional species filter
  if ( scalar @f_species ) {
    info('Filtering by species');
    @sources = grep { my $source = $_; grep { !scalar @{$source->coord_systems} || $source->matches_species( $_ ) } @f_species } @sources;
  }
  
  # optional name filter
  if ( scalar @f_name ) {
    info('Filtering by name');
    @sources = grep { my $source = $_; grep { $source->matches_name( $_ ) } @f_name  } @sources;
  }
  
  # optional logic name filter
  if ( scalar @f_logic ) {
    info('Filtering by logic_name');
    @sources = grep { my $source = $_; grep { $source->logic_name eq $_ } @f_logic  } @sources;
  }
  
  if ( $f_id ) {
    info('Filtering by identifier (logic_name or dsn)');
    @sources = grep { $_->logic_name eq $f_id || $_->dsn eq $f_id } @sources;
  }
  
  return [sort { lc $a->label cmp lc $b->label } @sources];
}

=head2 _parse_server

  Arg [..]   : none
  Example    : $parser->_parse_server( @servers );
  Description: Contacts the given DAS server(s) via the sources or dsn command
               and parses the results. Populates $self->{'_sources} as a hashref
               of DAS sources, organised by server:
               {
                http://... => [ Bio::EnsEMBL::ExternalData::DAS::Source, .. ],
               }
  Returntype : none
  Exceptions : If there is an error contacting the DAS registry/server.
  Caller     : fetch_Sources
  Status     : Stable

=cut
sub _parse_server {
  my ( $self, @servers ) = @_;
  
  # NOTE: this method technically supports multiple servers/locations, but
  #       in practice we expect to only be parsing one at a time
  $self->{'daslite'}->dsn(\@servers);
  
  # Servers which don't respond to the "sources" command will be attempted via
  # the "dsn" command
  my %success = ();
  my $struct = $self->{'daslite'}->sources();
  
  # Iterate over each server
  while (my ($url, $set) = each %{ $struct }) {
    
    info("Processing $url");
    my $status = $self->{'daslite'}->statuscodes($url);
    $url =~ s|/sources\??$||;
    $self->{'_sources'}{$url} = {};
    $set = $set->[0]->{'source'} || [];
    
    # If we get data back from the sources command, parse it
    if ($status =~ /^200/ && scalar @{ $set }) {
      $self->_parse_sources_output($url, $set);
      $success{$url} = 1;
    } else {
      info("$url does not support sources command; trying dsn");
    }
    
  }
  
  my @failed = grep { !$success{$_} } @servers;
  
  # Run the dsn command on the remaining servers (if any)
  if (scalar @failed) {
    
    $self->{'daslite'}->dsn(\@failed);
    $struct = $self->{'daslite'}->dsns();
    $self->{'daslite'}->dsn(\@servers);
    
    while (my ($url, $set) = each %{ $struct }) {
      info("Processing $url");
      my $status = $self->{'daslite'}->statuscodes($url);
      $url =~ s|/dsn\??$||;
      $set ||= [];
      
      # If we get data back from the sources command, parse it
      if ($status !~ /^200/) {
        throw("Error contacting DAS server '$url' : $status");
      } elsif (scalar @{ $set }) {
        $self->_parse_dsn_output($url, $set);
      }
    }
  }
  
}

=head2 _parse_sources_output

  Arg [1]    : The URL of the server
  Arg [2]    : Arrayref of sources, each being a hashref
  Example    : $parser->_parse_sources_output($server_url, $sources_set);
  Description: Parses the output of the sources command.
  Returntype : none
  Exceptions : none
  Caller     : _parse_server
  Status     : Stable

=cut
sub _parse_sources_output {
  my ($self, $server_url, $set) = @_;
  
  my $count = 0;
  
  # Iterate over the <SOURCE> elements
  for my $source (@{ $set }) {
    
    my $title       = $source->{'source_title'};
    my $homepage    = $source->{'source_doc_href'};
    my $description = $source->{'source_description'};
    my $email       = $source->{'maintainer'}[0]{'maintainer_email'};
    my $source_uri  = $source->{'source_uri'};
    
    # Iterate over the <VERSION> elements
    for my $version (@{ $source->{'version'} || [] }) {
      
      my ($url, $dsn);
      for my $cap (@{ $version->{'capability'} || [] }) {
        if ($cap->{'capability_type'} eq 'das1:features') {
          ($url, $dsn) = $cap->{capability_query_uri} =~ m|(.+/das1?)/(.+)/features|;
          last;
        }
      }
      $dsn || next; # this source doesn't support features command
      
      my $version_uri = $version->{'version_uri'};
      info("Parsing source $version_uri");
      
      # Now parse the coordinate systems and map to Ensembl's
      # This is the tedious bit, as some things don't map easily
      my @coords = ( );
      for my $coord (@{ $version->{'coordinates'} || [] }) {
        
        # Extract coordinate details
        my $auth    = $coord->{'coordinates_authority'};
        my $type    = $coord->{'coordinates_source'};
        # Version and species are optional:
        my $version = $coord->{'coordinates_version'};
        
        # Would be better to get species name via taxid, but that would require
        # mappings...
        my $cdata   = $coord->{'coordinates'};
        my (undef, undef, $species) = split /,/, $cdata, 3;
        
        if (!$type || !$auth) {
          warning("Unable to parse authority and sequence type for $version_uri ; skipping"); # Something went wrong!
          next;
        }
        
        if ( my $coord = $self->_parse_coord_system( $type, $auth, $version, $species ) ) {
          push @coords, $coord;
        }
      }
      
      # Create the actual source
      my $source = Bio::EnsEMBL::ExternalData::DAS::Source->new(
        -logic_name    => $source_uri,
        -url           => $url,
        -dsn           => $dsn,
        -label         => $title,
        -description   => $description,
        -maintainer    => $email,
        -homepage      => $homepage,
        -coords        => \@coords,
      );
      $count++;
      
      $self->{'_sources'}{$server_url}{$source->full_url} ||= $source;
      
    } # end version loop
    
  } # end source loop
  
  info("Found $count sources");
  
  return undef;
}

=head2 _parse_dsn_output

  Arg [1]    : The URL of the server
  Arg [2]    : Arrayref of sources, each being a hashref
  Example    : $parser->_parse_dsn_output($server_url, $sources_set);
  Description: Parses the output of the dsn command.
  Returntype : none
  Exceptions : none
  Caller     : _parse_server
  Status     : Stable

=cut
sub _parse_dsn_output {
  my ($self, $server_url, $set) = @_;
  
  my $count = 0;
  
  # Iterate over the <DSN> elements
  for my $hash (@{ $set }) {
    
    my $source = Bio::EnsEMBL::ExternalData::DAS::Source->new(
      -url           => $server_url,
      -dsn           => $hash->{'source_id'},
      -label         => $hash->{'source'},
      -description   => $hash->{'description'},
    );
    
    $self->{'_sources'}{$server_url}{$source->full_url} ||= $source;
    $count++;
    
    # Try to find the coordinate systems from the mapmaster..
    if ( my $mapmaster = $self->_find_mapmaster( $source->full_url, $hash->{'mapmaster'} ) ) {
      $source->coord_systems( $mapmaster->coord_systems );
    }
    
  }
  
  info("Found $count sources");
  
  return undef;
  
}

sub _find_mapmaster {
  my ( $self, $source_url, $raw_url ) = @_;
  
  my $mapmaster = undef;
  
  if ( $raw_url ) {
    my ($map_server, $map_dsn) = $self->parse_das_string( $raw_url );
    
    if ($map_server && $map_dsn) {
      my $mapmaster_url = join '/', $map_server, $map_dsn;
      
      # If the mapmaster is on a "new" server, query it!
      if ( !exists $self->{'_sources'}{$map_server} ) {
        # Mapmaster servers can generate errors, but this isn't fatal
        eval {
          $self->fetch_Sources( -location => $map_server );
        };
        if ($@) {
          warning("Error parsing $source_url - bad mapmaster $mapmaster_url : $@")
        }
      }
      
      $mapmaster = $self->{'_sources'}{$map_server}{$mapmaster_url};
    }
  }
  
  return $mapmaster;
}

sub _parse_coord_system {
  my ( $self, $type, $auth, $version, $species ) = @_;
  
  if ( exists $COORD_MAPPINGS{$type} &&
       exists $COORD_MAPPINGS{$type}{$auth} &&
       exists $COORD_MAPPINGS{$type}{$auth}{$version} &&
       exists $COORD_MAPPINGS{$type}{$auth}{$version}{$species} ) {
    my $s = $COORD_MAPPINGS{$type}{$auth}{$version}{$species};
    return Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_string($s);
  }
  
  $type = $TYPE_MAPPINGS{$type}      || $type; # handle fringe cases
  $auth = $AUTHORITY_MAPPINGS{$auth} || $auth; # handle fringe cases
  $version ||= '';
  $species ||= '';
  $species =~ s/ /_/g; # DAS species use spaces, Ensembl uses underscores
  
  # Wizardry to convert to Ensembl coord_system
  if ( is_genomic($type) ) {
    # seq_region coordinate systems have ensembl equivalents
    if ( !$species ) {
      info("Genomic coordinate system has no species: $type $auth$version");
      return;
    }
    my $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new(
      -name    => lc $type,
      -version => $auth.$version,
      -species => $species
    );
    return $cs;
  }
  
  # otherwise use a 'fake' coordinate system like 'ensembl_gene'
  my $cs = $NON_GENOMIC_COORDS{$type}{$auth};
  if ( !$cs ) {
    info("Coordinate system not supported: $auth $type");
    return;
  }
  if ( $cs->species ne $species ) {
    $cs = $cs->new( -name    => $cs->name,
                    -version => $cs->version,
                    -species => $species,
                    -label   => $cs->label );
  }
  
  return $cs;
}

# Convert some form of DAS source identifier into a server URI and relative
# source URI. Where no reliable inference can be made, a server URI is returned
# but no DSN (rather than the other way around).
# e.g. http://server/das             -> http://server/das              + undef
#      http://server/das/            -> http://server/das              + undef
#      http://server/das/foo         -> http://server/das              + foo
#      file://server/das/foo         -> file://server/das              + foo
#      http://server/das/sources/foo -> http://server/das              + foo
#      server/das/foo                -> http://server/das              + foo
#      server/das/sources/foo        -> http://server/das              + foo
#      foo                           -> http://foo/das                 + undef
sub parse_das_string {
  my ( $self, $in ) = @_;
  # OK... start the analysis...
  if ($in !~ m{^\w+:}) {
    $in = "http://$in"; # if no scheme, assume http
  }
  
  my $server = URI->new($in)->canonical;
  my $dsn    = URI->new();
  my $path = $server->path;
  $path =~ s|/+|/|g; # // -> /
  $server->path($path);
  
  my @segs = $server->path_segments;
  my @server_segs = ();
  my @dsn_segs = ();
  my $found = 0;
  for my $seg ($server->path_segments) {
    $seg || next;
    if ($seg =~ /^das1?$/) {
      $found = 1;
    } elsif ($seg =~ /^sources|dsn$/) {
      next;
    } elsif ($found) {
      push @dsn_segs, $seg;
    } else {
      push @server_segs, $seg;
    }
  }
  
  $server->path_segments( @server_segs, 'das' );
  $dsn->path_segments( @dsn_segs );
  
  return ($server->as_string, $dsn->as_string);
}

sub is_genomic {
  my ($test) = @_;
  my $name = ref $test && $test->can('name') ? $test->name : $test;
  return $name =~ m/$GENOMIC_REGEX/i ? 1 : 0;
}

1;
