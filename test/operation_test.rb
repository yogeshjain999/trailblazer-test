require "test_helper"

class OperationTest < Minitest::Spec
  class Create
    def self.call(params:)
      if params[:band] == "Rancid"
        model = Struct.new(:title, :band).new(params[:title].strip, params[:band])
        Result.new(true, model, nil)
      else

        Result.new(false, nil, Errors.new(band: ["must be Rancid"]))
      end
    end
  end

  class Update
    def self.call(params:, current_user:)
      return Result.new(false, nil, Errors.new(nil, Policy.new(false))) if current_user.name != "allowed"

      if params[:band] == "Rancid"
        model = Struct.new(:title, :band).new(params[:title].strip, params[:band])
        Result.new(true, model, nil)
      else

        Result.new(false, nil, Errors.new(band: ["must be Rancid"]))
      end
    end
  end

  include Trailblazer::Test::Assertions
  include Trailblazer::Test::Operation::Assertions

  let(:model) { Struct.new(:title, :band).new("__Timebomb__", "__Rancid__") }
  let(:user)    { Struct.new(:name).new("allowed") }
  let(:default_options) { {current_user: user} }

  #:exp-eq
  it do
    exp = assert_raises do
      input_params = {title: "Timebomb", band: "Rancid"}

      assert_pass Update, input_params, input_params
    end

    exp.inspect.include? %(NameError: undefined method `default_params')
  end
  #:exp-eq end

  #-
  # params is sub-set, expected is sub-set and both get merged with *_valid.
  #- simple: actual input vs. expected

  #:pass with params
  describe "Create with sane data" do
    let(:default_params) { {band: "Rancid"} }
    let(:expected_attrs) { {band: "Rancid", title: "Timebomb"} }

    # just works
    it { assert_pass Create, params(title: "Ruby Soho"), title: "Ruby Soho" }
    # trimming works
    it { assert_pass Create, params(title: "  Ruby Soho "), title: "Ruby Soho" }
  end
  #:pass with params end

  #:pass with ctx
  describe "Update with sane data" do
    let(:default_params) { {band: "Rancid"} }
    let(:expected_attrs) { {band: "Rancid", title: "Timebomb"} }

    # just works
    it { assert_pass Update, ctx(title: "Ruby Soho"), title: "Ruby Soho" }
    # trimming works
    it { assert_pass Update, ctx(title: "  Ruby Soho "), title: "Ruby Soho" }
  end
  #:pass with ctx end

  #:pass-block
  describe "Update with sane data" do
    let(:default_params) { {band: "Rancid"} }
    let(:expected_attrs) { {band: "Rancid", title: "Timebomb"} }

    it do
      assert_pass Update, ctx(title: " Ruby Soho"), {} do |result|
        assert_equal "Ruby Soho", result[:model].title
      end
    end
  end
  #:pass-block end

  #- simple: actual input vs. expected
  #:fail
  describe "Update with invalid data" do
    let(:default_params) { {band: "Rancid"} }

    it { assert_fail Update, ctx(band: "Adolescents"), [:band] }
  end
  #:fail end

  #- with block
  #:fail-block
  describe "Update with invalid data" do
    let(:default_params) { {band: "Rancid"} }

    it do
      assert_fail Update, ctx(band: " Adolescents") do |result|
        assert_equal({band: ["must be Rancid"]}, result["contract.default"].errors.messages)
      end
    end
  end
  #:fail-block end

  class CreateNestedParams
    def self.call(params:)
      if params[:form][:band] == "Rancid"
        model = Struct.new(:title, :band).new(params[:form][:title].strip, params[:form][:band])
        Result.new(true, model, nil)
      else

        Result.new(false, nil, Errors.new(band: ["must be Rancid"]))
      end
    end
  end

  describe "With nested params" do
    let(:default_params) { {form: {band: "Rancid"}} }
    let(:expected_attrs) { {band: "Rancid", title: "Timebomb"} }

    it { assert_pass CreateNestedParams, params(form: {title: "Ruby Soho"}), title: "Ruby Soho" }
    it { assert_fail CreateNestedParams, params(form: {band: nil}), [:band] }
    it { assert_fail CreateNestedParams, params(form: {band: "NOFX"}, deep_merge: false), [:band] }

    it "raise an error because params[:form] is nil" do
      exp = assert_raises do
        assert_fail CreateNestedParams, params(band: "NOFX", deep_merge: false), [:band]
      end

      exp.inspect.must_match %(NoMethodError: undefined method `strip' for nil:NilClass)
    end
  end

  include Trailblazer::Test::Operation::PolicyAssertions

  #:policy_fail-block
  describe "Update with failing policy" do
    let(:default_params) { {band: "Rancid"} }

    it do
      assert_policy_fail Update, ctx({title: "Ruby Soho"}, current_user: Struct.new(:name).new("not_allowed"))
    end
  end
  #:policy_fail-block end
end
