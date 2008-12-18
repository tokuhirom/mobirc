? my $rows = shift;

? wrap {

<div class="ttlLv1">keyword</div>
? for my $row (@$rows) {
?=     include('parts/keyword_line', $row)
? }

?= include('mobile/_go_to_top')

? }
