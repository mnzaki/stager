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
  if (!branches) branches = [];
  this.branches = ko.observableArray(branches.map(function (name) {
    return new Branch(this, name);
  }, this));
}

function Slot(name, currentFork, currentBranch) {
  this.name = name;
  this.currentFork = currentFork;
  this.currentBranch = currentBranch;

  this.empty = ko.computed(function () {
    return !this.currentFork;
  });
}

function ViewModel(forks_data) {
  var slots = [];
  $.each(slots_data, function (slot, info) {
    slots.push(new Slot(slot, info.currentFork, info.currentBranch));
  });
  this.slots = ko.observableArray(slots);

  var forks = [];
  $.each(forks_data, function (owner, info) {
    forks.push(new Fork(owner, info.name, info.branches));
  });
  this.forks = ko.observable(forks);

  this.filter = ko.observable('');

  this.filter_regex = ko.computed(function() {
    return RegExp(this.filter().trim().split(' ').join('.*'));
  }, this);

  this.to_stage = ko.observable();
}

// AJAX handlers
function handle_stage_response(data, textStatus, jqXHR) {
}

$(function() {
  var vm = new ViewModel(forks_data);
  ko.applyBindings(vm);

  $('#forks').delegate('.fork_branch .stage', 'click', function (e) {
    e.preventDefault();
    var context = ko.contextFor(this);
    vm.to_stage(context.$data);
    $.fancybox($('#slot_chooser'));
  });

  $('#slot_chooser .slot').click(function (e) {
    e.preventDefault();
    var data = ko.dataFor(this);
    $.post('/slot/' + data.name + '/stage', { fork: vm.to_stage().fork.name, branch: vm.to_stage().name }, handle_stage_response);
    $.fancybox.close($(this));
  });
});
