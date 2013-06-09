function Fork(owner, name, branches) {
  this.owner = owner;
  this.name = name;
  this.fork_name = owner + '/' + name;
  this.branches = ko.observableArray(branches);
}

function ForksViewModel(forks_data) {
  var forks = [];
  $.each(forks_data, function (owner, info) {
    var branches = [];
    if (info.branches) {
      $.each(info.branches, function(i, branch_name) {
        branches.push(branch_name);
      });
    }
    forks.push(new Fork(owner, info.name, branches));
  });

  this.forks = ko.observableArray(forks);

  this.filter = ko.observable('');
  this.filter_regex = ko.computed(function() {
    return RegExp('(' + this.filter().trim().split(" ").join("|") + ')+');
  }, this);

  this.branch_matches = function (fork, branch) {
    if (this.filter() === '') return true;
    return this.filter_regex().test(fork.owner + fork.name + branch);
  }
}

$(function() {
  var forks_vm = new ForksViewModel(forks_data);
  ko.applyBindings(forks_vm);
});
