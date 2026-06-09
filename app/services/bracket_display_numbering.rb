# frozen_string_literal: true

# Assigns each bracket node a stable, leaf-first display number (byes skipped),
# matching the order results are entered. Works on any node type that defines a
# PARENT_ASSOCIATIONS constant ([:parent_fight_1, :parent_fight_2] for Fight,
# [:parent_encounter_1, :parent_encounter_2] for Encounter) and responds to
# #bye?, #round, #position, #id. Parents must be preloaded (Fight.preload_parents
# / Encounter.preload_parents) so traversal does not re-query.
class BracketDisplayNumbering
  def self.for(records)
    new(records).numbers
  end

  def initialize(records)
    @records = records
  end

  def numbers
    @numbers = {}
    @counter = 0
    root_records.each { |record| assign(record) }
    @numbers
  end

  private attr_reader :records

  private def assign(record)
    return if record.nil?

    parents(record).each { |parent| assign(parent) }
    return if record.bye?

    @counter += 1
    @numbers[record.id] = @counter
  end

  private def parents(record)
    record.class::PARENT_ASSOCIATIONS.map { |name| record.public_send(name) }
  end

  private def parent_ids_of(record)
    record.class::PARENT_ASSOCIATIONS.map { |name| record.public_send(:"#{name}_id") }
  end

  private def root_records
    referenced = records.flat_map { |record| parent_ids_of(record) }.compact.to_set
    records.reject { |record| referenced.include?(record.id) }
      .sort_by { |record| [record.round.to_i, record.position.to_i] }
  end
end
