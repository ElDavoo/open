#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext tests => 12;
fixtures(qw( empty ));

BEGIN {
    use_ok 'Socialtext::Page';
    use_ok 'Socialtext::String';
    use_ok 'Socialtext::Jobs';
    use_ok 'Socialtext::JobCreator';
}

my $hub       = new_hub('empty');
my $page_name = 'Page ' . time();
my $page_id   = Socialtext::String::title_to_id($page_name);

# Create an empty page
my $page = Socialtext::Page->new( hub => $hub )->create(
    title   => $page_name,
    content => "No widget here",
    creator => $hub->current_user,
);

# Page should have no values
$page = $hub->pages->new_from_name($page_name);
my $values = $page->values();
is scalar keys %$values, 0, "Page without widget has no values";

# Add an empty widget, still should have no values
$page->edit_rev();
$page->content('This has a widget, but it is empty {values: }');
$page->store(user => $hub->current_user);
$page = $hub->pages->new_from_name($page_name);
$values = $page->values();
is scalar keys %$values, 0, "Page with empty widget has no values";

# Add a widget, should now have values
$page->edit_rev();
$page->content('This has a widget with content {values: "the title" field_1:The Label:type:"The Value" field_2:The Other Label:type:"The Other value"}');
$page->store(user => $hub->current_user);
$page = $hub->pages->new_from_name($page_name);
$values = $page->values();
is scalar keys %$values, 2, "Page has two values";
is $values->{'The Label'}, 'The Value', "'The Label' field has the right value";
is $values->{'The Other Label'}, 'The Other value', "'The Other Label' field has the right value";

# Two widgets on the page, last widget has value precidence
$page->edit_rev();
$page->content('This has a widget with content
{values: "the title" field_1:The Label:type:"The Value" field_2:The Other Label:type:"The Other value"}
{values: "the title" field_1:The Label:type:"Value 2"}

And some text after
');
$page->store(user => $hub->current_user);
$page = $hub->pages->new_from_name($page_name);
$values = $page->values();
is scalar keys %$values, 2, "Page has two values";
is $values->{'The Label'}, 'Value 2', "'The Label' field has the last value";
is $values->{'The Other Label'}, 'The Other value', "'The Other Label' field has the right value";

# Let the indexing catch up
my $jobs = Socialtext::Jobs->instance;
$jobs->clear_jobs;

# Now search for page with a value
$page->edit_rev();
$page->content('Sample story widget
{values: "Story" field_1:Dev Lead:type:"brandon" field_2:QA Lead:type:"ken"}
');
$page->store(user => $hub->current_user);
$jobs->work_once();

