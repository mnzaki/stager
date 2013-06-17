var slots_info_update_interval = 2000;
var vm;

function Branch(fork, name) {
  this.fork = fork;
  this.name = name;
  this.filter_text = fork.name + name;

  this.matches = function (regex) {
    if (!regex) return true;
    return regex.test(this.filter_text);
  }
}

function Fork(owner, name, branches) {
  this.name = owner + '/' + name;

  this.branches = ko.observableArray([]);

  this.setBranches = function (branches) {
    this.branches(branches.map(function (name) {
        return new Branch(this, name);
    }, this));
  };

  this.setBranches(branches || [])
}

function Slot(name, currentFork, currentBranch, status) {
  this.name = name;
  this.currentFork = currentFork;
  this.currentBranch = currentBranch;
  this.status = status;

  this.empty = ko.computed(function () {
    return !this.currentFork;
  });
}

function ViewModel(forks_info) {
  this.slots = ko.observableArray([]);

  var forks = [];
  $.each(forks_info, function (owner, info) {
    forks.push(new Fork(owner, info.name, info.branches));
  });
  this.forks = ko.observable(forks);

  this.filter = ko.observable('');

  this.filter_regex = ko.computed(function() {
    return RegExp(this.filter().trim().split(' ').join('.*'), 'i');
  }, this);

  this.to_stage = ko.observable();

  this.setSlots = function (slots_info) {
    var slots = [];
    $.each(slots_info, function (slot, info) {
      slots.push(new Slot(info.name, info.current_fork, info.current_branch, info.status));
    });
    this.slots(slots);
  };
}

function update_slots_info(data, textStatus, jqXHR) {
  vm.setSlots(data);
  setTimeout(function () { $.getJSON('/slots.json', update_slots_info); },
             slots_info_update_interval);
}

// AJAX handlers
function handle_stage_response(data, textStatus, jqXHR) {
}

function handle_fork_info_response(koData, jsonData) {
  koData.setBranches(jsonData.branches);
}

$(function() {
  vm = new ViewModel(forks_info);
  ko.applyBindings(vm);

  $('#forks')
  .delegate('.fork_branch .stage', 'click', function (e) {
    e.preventDefault();
    var context = ko.contextFor(this);
    vm.to_stage(context.$data);
    $.fancybox($('#slot_chooser'));
  })
  .delegate('.refresh_fork', 'click', function (e) {
    e.preventDefault();
    var koData = ko.dataFor(this);
    $.getJSON('/fork/' + koData.name + '.json', function (data, textStatus, jqXHR) {
      handle_fork_info_response(koData, data);
    });
  });

  $('#slot_chooser .slot').click(function (e) {
    e.preventDefault();
    var data = ko.dataFor(this);
    $.post('/slot/' + data.name + '/stage',
      { fork: vm.to_stage().fork.name,
        branch: vm.to_stage().name },
      handle_stage_response
    );
    $.fancybox.close($(this));
  });

  update_slots_info(slots_info, null, null);
});
