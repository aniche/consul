class Budget < ActiveRecord::Base

  include Measurable
  include Sluggable

  PHASES = %w(drafting accepting reviewing selecting valuating publishing_prices
              balloting reviewing_ballots finished).freeze
  ON_HOLD_PHASES = %w(reviewing valuating publishing_prices reviewing_ballots).freeze
  PUBLISHED_PRICES_PHASES = %w(publishing_prices balloting reviewing_ballots finished).freeze

  CURRENCY_SYMBOLS = %w(€ $ £ ¥).freeze

  validates :name, presence: true, uniqueness: true
  validates :phase, inclusion: { in: PHASES }
  validates :currency_symbol, presence: true
  validates :slug, presence: true, format: /\A[a-z0-9\-_]+\z/

  has_many :investments, dependent: :destroy
  has_many :ballots, dependent: :destroy
  has_many :groups, dependent: :destroy
  has_many :headings, through: :groups

  before_validation :sanitize_descriptions

  scope :on_hold, -> { where(phase: ON_HOLD_PHASES) }
  scope :drafting, -> { where(phase: "drafting") }
  scope :accepting, -> { where(phase: "accepting") }
  scope :reviewing, -> { where(phase: "reviewing") }
  scope :selecting, -> { where(phase: "selecting") }
  scope :valuating, -> { where(phase: "valuating") }
  scope :publishing_prices, -> { where(phase: "publishing_prices") }
  scope :balloting, -> { where(phase: "balloting") }
  scope :reviewing_ballots, -> { where(phase: "reviewing_ballots") }
  scope :finished, -> { where(phase: "finished") }

  scope :current, -> { where.not(phase: "finished") }

  def description
    send("description_#{phase}").try(:html_safe)
  end

  def self.description_max_length
    2000
  end

  def self.title_max_length
    80
  end

  def drafting?
    phase == "drafting"
  end

  def accepting?
    phase == "accepting"
  end

  def reviewing?
    phase == "reviewing"
  end

  def selecting?
    phase == "selecting"
  end

  def valuating?
    phase == "valuating"
  end

  def publishing_prices?
    phase == "publishing_prices"
  end

  def balloting?
    phase == "balloting"
  end

  def reviewing_ballots?
    phase == "reviewing_ballots"
  end

  def finished?
    phase == "finished"
  end

  def published_prices?
    PUBLISHED_PRICES_PHASES.include?(phase)
  end

  def balloting_process?
    balloting? || reviewing_ballots?
  end

  def balloting_or_later?
    balloting_process? || finished?
  end

  def on_hold?
    ON_HOLD_PHASES.include?(phase)
  end

  def current?
    !finished?
  end

  def heading_price(heading)
    heading_ids.include?(heading.id) ? heading.price : -1
  end

  def translated_phase
    I18n.t "budgets.phase.#{phase}"
  end

  def formatted_amount(amount)
    ActionController::Base.helpers.number_to_currency(amount,
                                                      precision: 0,
                                                      locale: I18n.default_locale,
                                                      unit: currency_symbol)
  end

  def formatted_heading_price(heading)
    formatted_amount(heading_price(heading))
  end

  def formatted_heading_amount_spent(heading)
    formatted_amount(amount_spent(heading))
  end

  def investments_orders
    case phase
    when 'accepting', 'reviewing'
      %w{random}
    when 'publishing_prices', 'balloting', 'reviewing_ballots'
      %w{random price}
    else
      %w{random confidence_score}
    end
  end

  def email_selected
    investments.selected.each do |investment|
      Mailer.budget_investment_selected(investment).deliver_later
    end
  end

  def email_unselected
    investments.unselected.each do |investment|
      Mailer.budget_investment_unselected(investment).deliver_later
    end
  end

  private

    def sanitize_descriptions
      s = WYSIWYGSanitizer.new
      PHASES.each do |phase|
        sanitized = s.sanitize(send("description_#{phase}"))
        send("description_#{phase}=", sanitized)
      end
    end
end

