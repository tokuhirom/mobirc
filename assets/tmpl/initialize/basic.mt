? my $form = shift;
? wrap {

<h1>mobirc setup menu</h1>

<?= encoded_string($form->render( req, 'hoge' )) ?>

? }
