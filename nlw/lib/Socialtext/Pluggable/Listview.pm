package Socialtext::Pluggable::Listview;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Exceptions;
use Socialtext::Pageset;
use Socialtext::String;
use Socialtext::l10n qw(loc);

sub _prepare_listview {
    my $self = shift;
    my $is_search = shift;

    my %cgi_vars = $self->cgi_vars;

    my $user = $self->user;

    eval { $self->_check_user($user) };
    $self->redirect('/') if $@;

    my ($accounts,$acct_group_set,$group_count) =
        $user->accounts_and_groups(plugin => 'people');
    my %acct_set = map { $_->account_id => 1 } @$accounts;

    Socialtext::Exception::Auth->throw(
        loc("not authorized: No Accounts have People enabled")."\n")
        unless @$accounts;

    my ($account_id, $all_accounts, $group_id);
    if ($cgi_vars{account_id}) {
        if ($cgi_vars{account_id} ne 'all') {
            $account_id = $cgi_vars{account_id};
        }
        else {
            $account_id   = 'all';
            $all_accounts = 1;
        }
    }
    elsif ($cgi_vars{group_id}) {
        $account_id = 'all';
        $all_accounts = 1;
        $group_id = $cgi_vars{group_id};
    }
    else {
        if ($cgi_vars{search_term}) {
            $account_id = 'all';
            $all_accounts = 1;
        }
        else {
            $account_id = $user->primary_account_id;
            if (!$acct_set{$account_id}) {
                # pick some people-enabled account
                $account_id = $accounts->[0]->account_id;
            }
        }
    }

    Socialtext::Exception::Auth->throw(loc("Not authorized to use this Account")."\n")
        unless ($account_id eq 'all' || $acct_set{$account_id});

    my $fields = 'email,position,location,work_phone';
    if ($all_accounts) {
        $fields .= ',accounts';
    }

    my $sortby;

    if ($is_search) {
        $sortby = $self->_store_and_get_search_sort_order;
    } else {
        $sortby = $cgi_vars{sortby} || 'best_full_name';
    }
    
    my $tag = delete $cgi_vars{tag};

    my $pageset = Socialtext::Pageset->new(
        cgi => {$self->cgi_vars},
        page_size => 20,
        max_page_size => 50,
    );

    my @list_args = (
        fields => $fields,
        sort => $sortby,
        viewer => $user,
        limit => $pageset->limit,
        offset => $pageset->offset,
    );
    push @list_args, tag => $tag if $tag;
    push @list_args, account_id => $account_id unless $all_accounts;
    push @list_args, group_id => $group_id if $group_id;

    my $title = $tag ? 
        loc("All People Tagged '[_1]'", $tag) :
        loc("All People");

    my @common = (
        unescaped_search_term => $cgi_vars{search_term},
        search_term => Socialtext::String::uri_escape($cgi_vars{search_term}),
        html_escaped_search_term =>
            Socialtext::String::html_escape($cgi_vars{search_term}),
    );

    my @template_args = (
        people_search => 1,
        container => { type => 'peoplelist' },
        viewer => $user,
        tag => $tag,
        predicate => 'action=people', # can be modified by caller
        title => $title,
        display_title => $title,
        sort_by => $sortby,
        people_selector => $group_id ? ";group_id=$group_id" :
                            ";account_id=$account_id",
        account_id => $account_id,
        group_id => $group_id, #maybe need name?
        accounts => $accounts,
        account_groups => $acct_group_set,
        @common,
    );

    my %other_args = (
        all_accounts => $all_accounts,
        pageset      => $pageset,
        acct_set     => \%acct_set,
        group_id     => $group_id,
        tag          => $tag,
        scope => $cgi_vars{scope} || '_',
        @common,
    );

    return (\@list_args, \@template_args, \%other_args);
}

sub _limit_result_accounts {
    my $rows = shift;
    my $acct_set = shift;
    # limit the listing down to accounts that the viewer also has (which
    # are people-enabled accounts)
    foreach my $row (@$rows) {
        @{$row->{accounts}} = grep { $acct_set->{$_->{account_id}} } 
                                   @{$row->{accounts}};
    }
}

sub _finish_listview {
    my $self = shift;
    my $rows = shift;
    my $template_args = shift;
    my $other_args = shift;

    _limit_result_accounts($rows,$other_args->{acct_set}) 
        if $other_args->{all_accounts};

    my $pageset = delete $other_args->{pageset};

    $self->template_render('view/peoplelist', 
        @$template_args, 
        rows => $rows,
        $pageset->template_vars(),
    );
}

sub _store_and_get_search_sort_order {
    my $self = shift;
    my %cgivars = $self->cgi_vars;
    my $cgi_sortby = $cgivars{sortby};

    if ($cgi_sortby) {
        $self->set_user_prefs(sortby => $cgi_sortby);
        return $cgi_sortby;
    }
    else {
        my $savedorder = $self->get_user_prefs->{sortby};
        return $savedorder || 'relevance';
    }
}

1;
