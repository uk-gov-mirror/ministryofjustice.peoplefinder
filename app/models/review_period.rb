class ReviewPeriod
  def open?
    !closed?
  end

  def closed?
    ENV['REVIEW_PERIOD'] == 'CLOSED'
  end

  def send_closure_notifications
    return if open?
    participants.each do |participant|
      UserMailer.
        closure_notification(participant, participant.tokens.create).
        deliver
    end
  end

  def participants
    Review.all.map { |r| [r.subject, r.subject.manager].compact }.flatten.uniq
  end
end
