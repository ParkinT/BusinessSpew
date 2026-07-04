# lib/invite_code_validator.rb
#
# Validates invite codes against a fixed set of structural rules:
#   - Total length must not exceed 13 characters
#   - Among the last four characters, at least three must be numerals
#   - Those numerals must sum to exactly 13
#
# Usage:
#   require_relative 'lib/invite_code_validator'
#   InviteCodeValidator.valid?("abc4441")  # => true
#   InviteCodeValidator.valid?("abc941")   # => false (9+4+1=14)
#
module InviteCodeValidator
  extend self

  MAX_LENGTH       = 13
  REQUIRED_DIGITS  = 3
  REQUIRED_SUM     = 13
  WINDOW           = 4

  def valid?(code)
    return false if code.nil? || code.strip.empty?
    return false if code.length > MAX_LENGTH

    digits = last_digits(code)

    digits.length >= REQUIRED_DIGITS && digits.sum == REQUIRED_SUM
  end

  # Returns a human-readable reason for failure — useful for
  # logging and debugging without exposing the algorithm to end users.
  def failure_reason(code)
    return "Code is blank"                          if code.nil? || code.strip.empty?
    return "Code exceeds #{MAX_LENGTH} characters"  if code.length > MAX_LENGTH

    digits = last_digits(code)

    return "Insufficient numerals in last #{WINDOW} characters" if digits.length < REQUIRED_DIGITS
    return "Numerals do not sum to #{REQUIRED_SUM}"             if digits.sum != REQUIRED_SUM

    nil
  end

  private

  def last_digits(code)
    code.chars.last(WINDOW).select { |c| c.match?(/\d/) }.map(&:to_i)
  end
end
