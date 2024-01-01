# frozen_string_literal: true

class KenshiForm < ApplicationForm
  attr_reader :cup, :user, :kenshi, :personal_info, :participations, :purchases

  validate :validate_kenshi, :validate_personal_info, :validate_participations, :validate_purchases

  delegate :id, :persisted?, to: :kenshi, allow_nil: true

  def initialize(cup:, user:, kenshi:)
    @cup = cup
    @user = user
    @kenshi = kenshi || @cup.kenshis.new(user: @user)
    @personal_info = kenshi.personal_info || @kenshi.build_personal_info
    @participations = kenshi.participations
    @purchases = kenshi.purchases
  end

  def save(params)
    build_kenshi(params[:kenshi])
    build_personal_info(params[:personal_info])
    build_participations(params[:participations])
    build_purchases(params[:purchases])

    return false if invalid?

    @kenshi.save!
  end

  private def build_kenshi(params)
    return unless params

    @kenshi.assign_attributes(params)
  end

  private def build_personal_info(params)
    if params
      @personal_info.assign_attributes(params)
    else
      @personal_info = nil
    end
  end

  private def build_participations(params)
    return unless params

    params.each do |_, participation_params|
      if participation_params[:category_type] == "TeamCategory"
        build_team_participation(participation_params)
      elsif participation_params[:category_type] == "IndividualCategory"
        build_individual_participation(participation_params)
      end
    end
    @participations = @participations.uniq
  end

  private def build_team_participation(params)
    category = TeamCategory.find(params[:category_id])
    if params[:ronin] == "0" && params[:team_name].blank?
      participations = @participations.to_a.select { |p| p.category == category }
      return if participations.empty?

      participations.each(&:mark_for_destruction)
      @participations += participations
    else
      participation = Participation.find_or_initialize_by(category: category, kenshi: @kenshi)
      participation.assign_attributes(
        ronin: params[:ronin] == "1",
        team_name: params[:team_name]
      )
      @participations << participation
    end
  end

  private def build_individual_participation(params)
    category = IndividualCategory.find(params[:category_id])
    if params[:save] == "0"
      participations = @participations.to_a.select { |p| p.category == category }
      return if participations.empty?

      participations.each(&:mark_for_destruction)
      @participations += participations
    else
      participation = Participation.find_or_initialize_by(category: category, kenshi: @kenshi)
      @participations << participation
    end
  end

  private def build_purchases(params)
    return unless params

    params.each do |_, purchase_params|
      product = Product.find(purchase_params[:product_id])
      if purchase_params[:save] == "0"
        purchases = @purchases.to_a.select { |p| p.product == product }
        next if purchases.empty?

        purchases.each(&:mark_for_destruction)
        @purchases += purchases
      else
        purchase = Purchase.find_or_initialize_by(product: product, kenshi: @kenshi)
        @purchases << purchase
      end
    end
    @purchases = @purchases.uniq
  end

  private def validate_kenshi
    return unless @kenshi

    promote_errors(@kenshi) if @kenshi.invalid?
  end

  private def validate_personal_info
    return unless @personal_info

    promote_errors(@personal_info) if @personal_info.invalid?
  end

  private def validate_participations
    @participations.each do |participation|
      promote_errors(participation) if participation.invalid?
    end
  end

  private def validate_purchases
    @purchases.each do |purchase|
      promote_errors(purchase) if purchase.invalid?
    end
  end
end
