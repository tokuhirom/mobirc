function ts() { return (new Date()).getTime(); }
var load_url;
function contents_load(url) {
    $('#contents').load(url+'?time='+ts());
    load_url = url;
}
function send_message() {
    $.post(load_url, {"msg":($('#msg').get())[0].value}, function (html) {
        $('#contents').html(html);
    });
}
setInterval(function(){ if(load_url){ contents_load(load_url); } }, 30000);
