#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  topthat.pl
#
#        USAGE:  ./topthat.pl  
#
# REQUIREMENTS:  Net::Google::Analytics
#                Config::YAML
#                Date::Calc
#                Date::Manip
# 
#         BUGS:  ---
#        NOTES:  Tutorial: https://metacpan.org/module/Net::Google::Analytics
#       AUTHOR:  Tom Purl (), tom@tompurl.com
#      VERSION:  1.0
#      CREATED:  10/17/2012
#===============================================================================

use Modern::Perl 2011;
use autodie;

use Net::Google::Analytics;
use Net::Google::Analytics::OAuth2;

use Config::YAML;
use Date::Calc qw(Add_Delta_Days);
use Time::localtime;
use Date::Manip;
use Cwd;
use Scalar::Util qw(looks_like_number);
use Pod::Usage;
use Getopt::Long;

use constant TRUE => 1;
use constant FALSE => 0;

# Property bag for this script
my %properties;

sub read_command_line_input {

    my $opt_help                            = FALSE;
    my $opt_man_page                        = FALSE;
    $properties{'reporting_period_in_days'} = 30;
    $properties{'verbose'}                  = FALSE;
    $properties{'html'}                     = FALSE;
    $properties{'config_file_path'}         = $ENV{'HOME'} . "/.topthat.yml";
    $properties{'results_number'}           = 11;

    my $are_valid_options = GetOptions (
                "help|h|?"             => \$opt_help,
                "reporting_period|r=i" => \$properties{'reporting_period_in_days'},
                "man|m"                => \$opt_man_page,
                "html"                 => \$properties{'html'},
                "config_file|c=s"      => \$properties{'config_file_path'},
                "results_number|n=i"   => \$properties{'results_number'},
                "verbose|v"            => \$properties{'verbose'}
    );

    pod2usage(1) if $are_valid_options == FALSE;
    pod2usage(1) if $opt_help;
    pod2usage(-exitstatus => 0, verbose => 2) if $opt_man_page;

    if (! -r $properties{'config_file_path'}) {
        print STDERR "ERROR: Invalid config file path: " . 
                       $properties{'config_file_path'}   .
                       "\n";
        pod2usage(1);
    } 

}    

sub read_config_file_input {

    my $config = Config::YAML->new(config => $properties{'config_file_path'});

    # Required fields
    $properties{'profile_id'}    = $config->get_profile_id;
    $properties{'client_id'}     = $config->get_client_id;
    $properties{'client_secret'} = $config->get_client_secret;
    $properties{'refresh_token'} = $config->get_refresh_token;
    $properties{'out_file_path'} = $config->get_out_file_path;

    # Non-required
    if (defined $config->get_verbose) {
        $properties{'verbose'} = $config->get_verbose;
    }
    if (defined $config->get_reporting_period_in_days) {
        $properties{'reporting_period_in_days'} = $config->get_reporting_period_in_days;
    }

}

# Validate and assign default values if neccessary.
sub validate_properties {

    # Nothing yet :)

}

sub print_properties {
    my %properties = @_;

    foreach my $key (keys %properties) {
        print "DEBUG: $key = ". $properties{$key} . "\n";
    }
}

sub read_input {

    read_command_line_input();
    read_config_file_input();
    validate_properties();

    if ($properties{'verbose'}) {
        print_properties(%properties);
    }

}

sub authenticate {

    my $analytics = Net::Google::Analytics->new;

    my $oauth = Net::Google::Analytics::OAuth2->new(
        client_id     => $properties{'client_id'},
        client_secret => $properties{'client_secret'},
    );

    my $token = $oauth->refresh_access_token($properties{'refresh_token'});
    $analytics->token($token);

    return $analytics;

}

# Expects an integer date offset. 0 = today, 1 = tomorrow, -1 = yesterday
sub date_from_offset {
    my $offset = shift;
    if (! looks_like_number($offset)) {
        print STDERR "ERROR: Invalid offset value: $offset\n";
        exit 1;
    }

    # Calculate dates
    my $lt = localtime;
    (my $today, my $thismonth, my $thisyear) = ($lt->mday, $lt->mon, $lt->year);
    $thisyear +=1900;
    $thismonth +=1;
    print STDOUT "OUT: $thisyear, $thismonth, $today, $offset\n";
    (my $otheryear, my $othermonth, my $otherday) = Add_Delta_Days($thisyear, $thismonth, $today, $offset);

    # Format the date
    my $date_raw = ParseDate(($otheryear) . "-" 
                           . ($othermonth)   . "-"  
                           .  $otherday);
    my $date_fmt = UnixDate($date_raw, '%Y-%m-%d');
    print STDOUT "Formated date: $date_fmt\n";

    return $date_fmt;
}

sub send_request {
    my ($analytics_conn, $start_date, $end_date) = @_; 

    # Build request
    my $req = $analytics_conn->new_request(
        ids         => "ga:" . $properties{'profile_id'},
        dimensions  => "ga:pageTitle,ga:pagePath",
        metrics     => "ga:pageviews,ga:uniquePageviews,ga:timeOnPage,ga:bounces,ga:entrances,ga:exits",
        sort        => "-ga:pageviews",
        start_date  => $start_date,
        end_date    => $end_date,
        max_results => $properties{'results_number'}
    );

    # Send request
    my $res = $analytics_conn->retrieve($req);
    die("GA error: " . $res->error_message) if !$res->is_success;

    return $res;

}

sub print_to_html {

    my $result_set = shift;

    open(OUT, "> " . $properties{'out_file_path'})
        or die "Couldn't open " . $properties{'out_file_path'} . " for writing\n";
    print OUT "<section>\n";
    print OUT "<h1>Most Popular</h1>\n";
    print OUT "<ul>\n"; 

    for my $row (@{ $result_set->rows }) {
        unless ($row->get_page_path eq '/') {
            print OUT "    <li><a href=\"" . $row->get_page_path . "\">" .
                           $row->get_page_title . "</a></li>\n";
        }
    }
                                            
    print OUT "</ul>\n";
    print OUT "</section>\n";
    close(OUT);
}

sub print_plain_to_stdout {

    my $result_set = shift; 
    my $place = 0;

    print "place,page title,page path,pageviews,unique page views, time on page,";
    print "bounces,entrances,exits";
    print "\n";

    for my $row (@{ $result_set->rows }) {
        $place++;
        print $place                     . "," .
              $row->get_page_title       . "," .
              $row->get_page_path        . "," .
              $row->get_pageviews        . "," .
              $row->get_unique_pageviews . "," .
              $row->get_time_on_page     . "," .
              $row->get_bounces          . "," .
              $row->get_entrances        . "," .
              $row->get_exits            . 
              "\n";
    }
}

sub debug_log {
    my $message = shift;
    print STDERR "DEBUG: $message\n"  if $properties{'verbose'};
}

### __main__

read_input();

debug_log("Authenticating...");
my $analytics_conn = authenticate();

my $start_date = date_from_offset(-$properties{'reporting_period_in_days'});
my $end_date   = date_from_offset(0);

debug_log("start_date = ". $start_date);
debug_log("end_date = ". $end_date);

debug_log("Retrieving results...");
my $result_set = send_request($analytics_conn,
                              $start_date,
                              $end_date);

if ($properties{'html'}) {
    debug_log("Printing results to an HTML file");
    print_to_html($result_set);
}

# TODO Send output to STDOUT
print_plain_to_stdout($result_set);
#print_prettyn_to_stdout($result_set);

debug_log("Complete!");

__END__

=head1 TITLE

topthat - A simple script that retrieves a list of the most popular web pages 
          on a site according to Google Analytics.

=head1 SYNOPSIS

topthat.pl [options]

 Options:
   -h,-?,--help                 Brief help message
   -m,--man                     Full documentation
   --html                       Create a simple HTML report of the results.
   -v,--verbose                 Show verbose output
   -r,--reporting_period=DAYS   The reporting period starting today.
   -c,--config_file=PATH        The config file that you would like to use. 
                                This defaults to ~/.topthatrc
   -n,--results_number=NUM      The number of results you would like the script
                                to return. The default is 10
=head1 DESCRIPTION

This is a simple script that you can use to grab a list of your most-visited
web pages according to Google Analytics. Also, if you would like to take the 
results.

=head1 OPTIONS

=over 8

=item B<-h,-?,--help>

Prints a brief help message.

=item B<-m,--man>

Prints the manual page for this script and then exits.

=item B<--html>

Creates an HTML "portlet" of the results that can be used in an Octopress site.

=item B<-v,--verbose>

Prints verbose information, including most of the property values. This is
usually only useful if you are troubleshooting a script error.

=item B<-r,--reporting_period=DAYS>

This is the number of days back you want to go in your report, starting today.
So a value of 30 would give you the last 30 days' worth of data, for example.

=item B<-c,--config_file=PATH>

The location of the YAML config file. This is important and necessary since not
all information can be included as command-line options. By default, these
config options are read from $HOME/.topthatrc.

=item B<-n,--results_number=NUMBER>

The number of results that you want returned. By default this is 11 because it
is assumed that your home page ("/") will be in the top 10 list, and that
result is automatically filtered out.

=back 

=head1 CONFIGURATION FILE OPTIONS

In addition to the configuration options, there are options that need to be
specified in a configuration file.

TODO

=head1 REQUIREMENTS

TODO

=head1 AUTHOR

Tom Purl <tom@tompurl.com>

=cut





