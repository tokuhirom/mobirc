
var form = document.getElementById("input");
if (form) {
    form.addEventListener("submit", function (e) {
        e.preventDefault();

        var value = form.querySelector("input[name=msg]").value;

        $.post(form.action, {
            msg : value
        }, function (data) {
            location.reload();
        });
    }, false);
}

var more = document.querySelectorAll('div.more a');
for (var i = 0, len = more.length; i < len; i++) {
    var href = more[i].href;
    more[i].href = 'javascript:location.replace("'+href+'")';
}

