? my $form = shift;
? wrap {

<h1>irc connection</h1>

?= encoded_string($form->render(req, 'hoge'))

? }
