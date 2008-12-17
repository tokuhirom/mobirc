? require_wrap()

? my $rows = shift;
<div class="ttlLv1">keyword</div>
? for my $row (@$rows) {
    <?= encoded_string App::Mobirc::Web::Template::Parts->keyword_line( $row ) ?>
? }

?= include('mobile/_go_to_top')
