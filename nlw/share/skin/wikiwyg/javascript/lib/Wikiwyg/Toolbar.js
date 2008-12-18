/*==============================================================================
This Wikiwyg class provides toolbar support

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

proto = new Subclass('Wikiwyg.Toolbar', 'Wikiwyg.Base');
proto.classtype = 'toolbar';

proto.config = {
    divId: null,
    imagesLocation: 'images/',
    imagesExtension: '.gif',
    selectorWidth: '100px',
    controlLayout: [
        'save', 'cancel', 'mode_selector', '/',
        // 'selector',
        'h1', 'h2', 'h3', 'h4', 'p', 'pre', '|',
        'bold', 'italic', 'underline', 'strike', '|',
        'link', 'hr', '|',
        'ordered', 'unordered', '|',
        'indent', 'outdent', '|',
        'table', '|',
        'help'
    ],
    styleSelector: [
        'label', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'pre'
    ],
    controlLabels: {
        save: 'Save',
        cancel: 'Cancel',
        bold: 'Bold (Ctrl+b)',
        italic: 'Italic (Ctrl+i)',
        underline: 'Underline (Ctrl+u)',
        strike: 'Strike Through (Ctrl+d)',
        hr: 'Horizontal Rule',
        ordered: 'Numbered List',
        unordered: 'Bulleted List',
        indent: 'More Indented',
        outdent: 'Less Indented',
        help: 'About Wikiwyg',
        label: '[Style]',
        p: 'Normal Text',
        pre: 'Preformatted',
        h1: 'Heading 1',
        h2: 'Heading 2',
        h3: 'Heading 3',
        h4: 'Heading 4',
        h5: 'Heading 5',
        h6: 'Heading 6',
        link: 'Create Link',
        unlink: 'Remove Linkedness',
        table: 'Create Table'
    }
};

proto.initializeObject = function() {
    if (this.config.divId) {
        this.div = document.getElementById(this.config.divId);
    }
    else {
        this.div = Wikiwyg.createElementWithAttrs(
            'div', {
                'class': 'wikiwyg_toolbar',
                id: 'wikiwyg_toolbar'
            }
        );
    }

    this.button_container = this.div;
    var config = this.config;
    for (var i = 0; i < config.controlLayout.length; i++) {
        var action = config.controlLayout[i];
        var label = config.controlLabels[action.replace(/\.png$/, '')];
        if (action == 'save')
            this.addControlItem(label, 'saveChanges');
        else if (action == 'cancel')
            this.addControlItem(label, 'cancelEdit');
        else if (action == 'mode_selector')
            this.addModeSelector();
        else if (action == 'selector')
            this.add_styles();
        else if (action == 'help')
            this.add_help_button(action, label);
        else if (action == '|')
            this.add_separator();
        else if (action == '{')
            this.add_div_open();
        else if (action == '}')
            this.add_div_close();
        else if (action == '/')
            this.add_break();
        else
            this.add_button(action, label);
    }
}

proto.enableThis = function() {
    this.button_container.style.display = 'block';
}

proto.disableThis = function() {
    this.button_container.style.display = 'none';
}

proto.setup_widgets_pulldown = function(title) {
    var widgets_list = Wikiwyg.Widgets.widgets;
    var widget_data = Wikiwyg.Widgets.widget;

    var tb = eval(this.classname).prototype;

    tb.styleSelector = [ 'label' ];
    for (var i = 0; i < widgets_list.length; i++) {
        var widget = widgets_list[i];
        if (! widget_data[widget].hide_in_menu) {
            tb.styleSelector.push('widget_' + widget);
        }
    }
    tb.controlLayout.push('selector');

    tb.controlLabels.label = title;
    for (var i = 0; i < widgets_list.length; i++) {
        var widget = widgets_list[i];
        if (! widget_data[widget].hide_in_menu) {
            tb.controlLabels['widget_' + widget] = widget_data[widget].label;
        }
    }
}

proto.make_button = function(type, label) {
    var base = this.config.imagesLocation;
    var ext = type.match(/\.png$/) ? '' : this.config.imagesExtension;
    type = type.replace(/\.png$/, '');
    return Wikiwyg.createElementWithAttrs(
        'img', {
            'class': 'wikiwyg_button',
            id: "wikiwyg_button_" + type,
            alt: label,
            title: label,
            src: base + type + ext
        }
    );
}

proto.add_button = function(type, label) {
    var img = this.make_button(type, label);
    var self = this;
    img.onclick = function() {
        self.wikiwyg.current_mode.process_command(type);
    };
    this.button_container.appendChild(img);
}

proto.add_help_button = function(type, label) {
    var img = this.make_button(type, label);
    var a = Wikiwyg.createElementWithAttrs(
        'a', {
            target: 'wikiwyg_button',
            href: 'http://www.wikiwyg.net/about/'
        }
    );
    a.appendChild(img);
    this.button_container.appendChild(a);
}

proto.add_separator = function() {
    var base = this.config.imagesLocation;
    var ext = this.config.imagesExtension;
    this.button_container.appendChild(
        Wikiwyg.createElementWithAttrs(
            'img', {
                'class': 'wikiwyg_separator',
                alt: ' | ',
                title: '',
                src: base + 'separator' + ext
            }
        )
    );
}

proto.add_div_open = function() {
    var base = this.config.imagesLocation;
    var ext = this.config.imagesExtension;
    var $div = jQuery('<div class="table_buttons"></div>');
    jQuery(this.button_container).append($div);
    this.button_container = $div[0];
}

proto.add_div_close = function() {
    this.button_container  = this.div;
}

proto.addControlItem = function(text, method) {
    var span = Wikiwyg.createElementWithAttrs(
        'span', { 'class': 'wikiwyg_control_link' }
    );

    var link = Wikiwyg.createElementWithAttrs(
        'a', { href: '#' }
    );
    link.appendChild(document.createTextNode(text));
    span.appendChild(link);
    
    var self = this;
    link.onclick = function() { eval('self.wikiwyg.' + method + '()'); return false };

    this.div.appendChild(span);
}

proto.resetModeSelector = function() {
    if (this.firstModeRadio) {
        var temp = this.firstModeRadio.onclick;
        this.firstModeRadio.onclick = null;
        this.firstModeRadio.click();
        this.firstModeRadio.onclick = temp;
    }
}

proto.addModeSelector = function() {
    var span = document.createElement('span');

    var radio_name = Wikiwyg.createUniqueId();
    for (var i = 0; i < this.wikiwyg.config.modeClasses.length; i++) {
        var class_name = this.wikiwyg.config.modeClasses[i];
        var mode_object = this.wikiwyg.mode_objects[class_name];
 
        var radio_id = Wikiwyg.createUniqueId();
 
        var checked = i == 0 ? 'checked' : '';
        var radio = Wikiwyg.createElementWithAttrs(
            'input', {
                type: 'radio',
                name: radio_name,
                id: radio_id,
                value: mode_object.classname,
                'checked': checked
            }
        );
        if (!this.firstModeRadio)
            this.firstModeRadio = radio;
 
        var self = this;
        radio.onclick = function() { 
            self.wikiwyg.switchMode(this.value);
        };
 
        var label = Wikiwyg.createElementWithAttrs(
            'label', { 'for': radio_id }
        );
        label.appendChild(document.createTextNode(mode_object.modeDescription));

        span.appendChild(radio);
        span.appendChild(label);
    }
    this.div.appendChild(span);
}

proto.add_break = function() {
    this.div.appendChild(document.createElement('br'));
}

proto.add_styles = function() {
    var options = this.config.styleSelector;
    var labels = this.config.controlLabels;

    this.styleSelect = document.createElement('select');
    this.styleSelect.className = 'wikiwyg_selector';
    if (this.config.selectorWidth)
        this.styleSelect.style.width = this.config.selectorWidth;

    for (var i = 0; i < options.length; i++) {
        value = options[i];
        var option = Wikiwyg.createElementWithAttrs(
            'option', { 'value': value }
        );
        option.appendChild(document.createTextNode(labels[value] || value));
        this.styleSelect.appendChild(option);
    }
    var self = this;
    this.styleSelect.onchange = function() { 
        self.set_style(this.value) 
    };
    this.div.appendChild(this.styleSelect);
}

proto.set_style = function(style_name) {
    var idx = this.styleSelect.selectedIndex;
    // First one is always a label
    if (idx != 0)
        this.wikiwyg.current_mode.process_command(style_name);
    this.styleSelect.selectedIndex = 0;
}
