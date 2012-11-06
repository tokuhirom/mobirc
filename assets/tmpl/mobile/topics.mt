? wrap {

? for my $server (global_context->servers) {
?   for my $channel ($server->channels) {
      <div class="OneTopic">
          <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>"><?= $channel->name ?></a><br />
          <span><?= $channel->topic ?></span><br />
      </div>
?   }
? }

?= include('mobile/_go_to_top')

? }
