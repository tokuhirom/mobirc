
var form = document.getElementById("input");
if (form) {
    form.addEventListener("submit", function (e) {
        e.preventDefault();

        var input = form.querySelector("input[name=msg]");
        input.disabled = true;
        input.style.background = "#ccc";
        
        var img = document.createElement("img");
        img.className = "loading";
        img.src = docroot + "static/loading.gif";

        form.appendChild(img);

        $.post(form.action, {
            msg : input.value
        }, function (data) {
        //    location.reload();
        });
    }, false);
}

var more = document.querySelectorAll('div.more a');
for (var i = 0, len = more.length; i < len; i++) {
    var href = more[i].href;
    more[i].href = 'javascript:location.replace("'+href+'")';
}

