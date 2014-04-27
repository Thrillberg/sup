class Meeting < ActiveRecord::Base
  has_many :meeting_members
  has_many :members, through: :meeting_members

  attr_accessible :member_ids, :meeting_date
  accepts_nested_attributes_for :members

  before_save :mark_members_not_left_out

  def mark_members_not_left_out
    members.each { |m| m.update_attribute(:left_out, false) }
  end

  # put everyone in a group, draw connections as edges
  # rank by edges
  # pick first by rank
  # pick second by rank that isn't connected to first
  # pick third by rank that isn't connected to either first or second
  def self.schedule_all
    exit_flag = false # talk about laziness
    ranks = Hash[Member.all.map do |member|
      edge_ids = member.edge_ids
      advantage = member.left_out ? 100 : 0
      [member.id, {edges: edge_ids, num_edges: edge_ids.count + advantage}]
    end]

    until ranks.empty?
      meeting_member_ids = []
      forbidden_member_ids = []
      until meeting_member_ids.length == 3
        pair = self.delete_max_rank(forbidden_member_ids, ranks, meeting_member_ids.length)
        if pair.nil?
          # at this point it is impossible to create any more triplets
          exit_flag = true
          # meeting_member_ids will be partially populated at this point
          [*ranks.keys, *meeting_member_ids].each { |member_id| Member.find(member_id).update_attribute(:left_out, true) }
        end
        break if exit_flag
        meeting_member_ids << pair.first
        forbidden_member_ids.concat(pair.last[:edges])
      end
      break if exit_flag
      Meeting.create(member_ids: meeting_member_ids, meeting_date: self.choose_date(meeting_member_ids))
    end
  end

  def self.trigger_weekly_email
    time_range = (3.days.ago..Time.now)
    Meeting.where(created_at: time_range).each do |meeting|
      MeetingMailer.new_meeting(meeting).deliver
    end
  end

  def self.trigger_weekly_debug_email
    time_range = (3.days.ago..Time.now)
    Meeting.where(created_at: time_range).each do |meeting|
      MeetingMailer.new_meeting_debug(meeting).deliver
    end
  end

  # TODO check calendars of members
  def self.choose_date(member_ids)
    nearest_monday = Date.commercial(Date.today.year, 1+Date.today.cweek, 1)
    return nearest_monday + rand(5).days
  end

  # mutates ranks!
  # we want to delete the max rank while also preventing the
  # future restricted ids from becoming everyone in sup
  def self.delete_max_rank(restricted_ids_arr, rem_ranks, num_paired)
    rem_ranks_copy = rem_ranks.dup
    restricted_ids_arr.each { |r_id| rem_ranks_copy.delete(r_id) }

    if rem_ranks_copy.empty?
      # if this happens then there are no more valid triplets in the rem_ranks
      nil
    else
      p_id, p_h = rem_ranks_copy.max_by do |id, h|
        if restricted_ids_arr.include?(id)
          next
        elsif num_paired == 1 && ([Member.count, (Member.count - 1)].include?((h[:edges] + restricted_ids_arr).uniq.length))
          # collectively, the restricted ids should not account
          # for everyone if this is the 2nd person in the triplet
          next
        else
          h[:num_edges]
        end
      end
      rem_ranks.delete(p_id)
      [p_id, p_h]
    end
  end

  # its not really predictable how the groups of 3 will be devided, so this is
  # a random enough yet consistent way of selecting a "leader" for each meeting
  def leader
    members.last
  end
end
#--
# generated by 'annotated-rails' gem, please do not remove this line and content below, instead use `bundle exec annotate-rails -d` command
#++
# Table name: meetings
#
# * id           :integer         not null
#   meeting_date :date
#   created_at   :datetime
#   updated_at   :datetime
#--
# generated by 'annotated-rails' gem, please do not remove this line and content above, instead use `bundle exec annotate-rails -d` command
#++
