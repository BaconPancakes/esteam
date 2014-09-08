$(document).ready(function(){

    var legend = $('legend');
    if (legend.attr('id') === 'Results'&& legend.text != 'Results') {
        legend.hide('fade', 300, function() {
            legend.text('Results')
        });
        legend.show('fade', 300);
    }
    var checkbox = $("input[name='saturated']");
    if (checkbox.attr('checked') === 'checked') {
        $('#quality_field').show();
    }
    else {
        $('#quality_field').hide();
    }
    checkbox.click(function() {
        if (this.checked) {
            $('#quality_field').show( "fade", 500);
        }
        else {
            $('#quality_field').hide("fade", 300);
        }
    })
    fixFooter();
});

function fixFooter() {
    var footer = $("#footer");
    var pos = footer.position();
    var height = $(window).height();
    height = height - pos.top;
    height = height - footer.height();
    if (height > 0) {
        footer.css({
            'margin-top': height + 'px'
        });
    }
}

function clearForm(oForm) {
    var elements = oForm.elements;
    var legendResult = $('legend#Results')
    legendResult.fadeOut(300, function() {
        legendResult.text("Enter Known Properties");
    });
    legendResult.fadeIn(300);
    $('#quality_field').hide("fade", 300);
    oForm.reset();

    for(i=0; i<elements.length; i++) {

        field_type = elements[i].type.toLowerCase();

        switch(field_type) {

            case "text":
            case "password":
            case "textarea":
            case "hidden":

                elements[i].value = "";
                break;

            case "radio":
            case "checkbox":
                if (elements[i].checked) {
                    elements[i].checked = false;
                }
                break;

            case "select-one":
            case "select-multi":
                elements[i].selectedIndex = -1;
                break;

            default:
                break;
        }
    }
}

