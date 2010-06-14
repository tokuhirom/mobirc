? my ($channel_name, $members) = @_

? wrap {

<h1>members in <B><?= $channel_name ?></B></h1>

?     for my $member (@$members) {
<?= $member ?><br />
?     }

<hr />

?= include('mobile/_go_to_top')

? }
