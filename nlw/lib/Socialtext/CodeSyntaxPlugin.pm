package Socialtext::CodeSyntaxPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';
use Class::Field qw(const);

sub class_id { 'code' }
const class_title    => 'CodeSyntaxPlugin';

our %Brushes = (
    bash => 'Bash',
    shell => 'Bash',
    csharp => 'CSharp',
    cpp => 'Cpp',
    c => 'Cpp',
    css => 'Css',
    diff => 'Diff',
    js => 'JScript',
    javascript => 'JScript',
    java => 'Java',
    perl => 'Perl',
    php => 'Php',
    python => 'Python',
    ruby => 'Ruby',
    sql => 'Sql',
    xml => 'Xml',
);

sub register {
    my $self = shift;
    my $registry = shift;
    for my $key (%Brushes) {
        $registry->add(
            wafl => "${key}_code" => 'Socialtext::CodeSyntaxPlugin::Wafl');
    }
}

package Socialtext::CodeSyntaxPlugin::Wafl;
use base 'Socialtext::Formatter::WaflBlock';
use strict;
use warnings;

sub html {
    my $self = shift;
    my $method = $self->method;
    (my $type = $method) =~ s/^(.+?)_code$/$1/;
    chomp(my $string = $self->html_unescape($self->block_text));
    my $js_base  = "/static/skin/common/javascript/SyntaxHighlighter";
    my $css_base = "/static/skin/common/css/SyntaxHighlighter";
    my $brush = $Socialtext::CodeSyntaxPlugin::Brushes{$type};

    return <<EOT;
<script type="text/javascript" src="$js_base/shCore.js"></script>
<script type="text/javascript" src="$js_base/shBrush${brush}.js"></script>
<link href="$css_base/shCore.css" rel="stylesheet" type="text/css" />
<link href="$css_base/shThemeDefault.css" rel="stylesheet" type="text/css" />
<pre class="brush: $type">
$string
</pre>
<script type="text/javascript">
     SyntaxHighlighter.all()
</script>
EOT
}

1;
