class OperationsManager
  attr_reader :slots

  def initialize(slots)
    @slots = slots.inject({}) do |hash, slot|
      hash[slot] = { currentFork: nil, currentBranch: nil }
      hash
    end
  end
end

