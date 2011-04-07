package CXGN::Biosource::Cmd::Role::DataStreamer;
use Moose::Role;
use namespace::autoclean;

has 'input_handles' => (
    is       => 'rw',
    isa      => 'ArrayRef',
    traits   => ['Array'],
    default  => sub { [] },
    handles => {
        'next_input_handle'  => 'shift',
        'have_input_handles' => 'count',
    },
    );

sub next_data {
    my ( $self ) = @_;

    return unless $self->have_input_handles;

    my $delim_line = qr/^-+\s*$/;
    my $accumulator = '';

    my $f = $self->input_handles->[0] = $self->ensure_fh( $self->input_handles->[0] );

    while( my $line = <$f> ) {
        if( $line =~ $delim_line ) {
            return $self->_parse_data( $accumulator );
        } else {
            $accumulator .= $line;
        }
    }
    # if we got here, this handle is done.
    $self->next_input_handle;
    return $self->_parse_data( $accumulator ) || $self->next_data;
}
sub _parse_data {
    my ( $self, $string ) = @_;
    return unless $string =~ /\S/;
    return { Config::General->new( -String => $string )->getall };
}

sub ensure_fh {
    my ( $self, $f ) = @_;
    my $ref = ref $f;
    return $f if $ref eq 'GLOB' || $ref && $f->can('getline');
    open my $fh, '<', $f or die "$! reading '$f'\n";
    return $fh;
}

1;
