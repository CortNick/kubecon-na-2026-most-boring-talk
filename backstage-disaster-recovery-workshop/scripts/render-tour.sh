#!/usr/bin/env bash
# Writes .tours/backstage-dr.tour from tours/backstage-dr.tour.tmpl. CodeTour reads tours from
# .tours/ in the workspace folder. Fills in:
#   {{BASE_URL}}                           the portal URL, known only at runtime
#   {{SNIPPET|<file>|<start>|<end>}}       a fenced code block with the lines of <file> from the
#                                          first line matching regex <start> to the next line
#                                          matching regex <end>, so every step shows the code it
#                                          talks about, cut from the real file, and nothing else
source "$(dirname "$0")/lib.sh"

url="$(base_url)"

mkdir -p "${ROOT_DIR}/.tours"
cd "${ROOT_DIR}"
URL="${url}" perl -pe '
  sub snippet {
    my ($file, $start, $end) = @_;
    open(my $fh, "<", $file) or die "render-tour: no file $file\n";
    my @lines; my $in = 0;
    while (my $l = <$fh>) {
      chomp $l;
      $in = 1 if !$in && $l =~ /$start/;
      next unless $in;
      push @lines, $l;
      last if $l =~ /$end/;
    }
    @lines or die "render-tour: no line matching /$start/ in $file\n";
    $lines[-1] =~ /$end/ or die "render-tour: no line matching /$end/ after /$start/ in $file\n";
    my ($indent) = sort { $a <=> $b } map { /^( *)/; length $1 } grep { /\S/ } @lines;
    s/^ {$indent}// for @lines;
    my $lang = $file =~ /\.ya?ml$/ ? "yaml" : $file =~ /\.sh$/ ? "bash" : "text";
    my $text = join("\n", "```$lang", @lines, "```");
    $text =~ s/\\/\\\\/g; $text =~ s/"/\\"/g; $text =~ s/\t/\\t/g; $text =~ s/\n/\\n/g;
    return $text;
  }
  s/\{\{BASE_URL\}\}/$ENV{URL}/g;
  s/\{\{SNIPPET\|([^|]+)\|([^|]+)\|([^|]+?)\}\}/snippet($1, $2, $3)/ge;
' tours/backstage-dr.tour.tmpl >.tours/backstage-dr.tour.partial
mv .tours/backstage-dr.tour.partial .tours/backstage-dr.tour
