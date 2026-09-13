# Action Text's sanitizer strips <table>/<tr>/<th>/<td> by default (Rails'
# safe-list sanitizer, whichever HTML4/HTML5 vendor actually resolves — same
# tags missing from both, confirmed via ActionText::ContentHelper.sanitizer.class
# in this app). Article bodies are authored by Daffa (admin CMS / seeds), never
# visitor input, and the Medium-style case-study format uses real tables (an
# "at a glance" summary, a config-value reference table), so the allowlist
# needs to grow rather than the content being rewritten around the gap.
[ Rails::HTML4::SafeListSanitizer, Rails::HTML5::SafeListSanitizer ].each do |sanitizer|
  sanitizer.allowed_tags = sanitizer.allowed_tags + %w[table thead tbody tr th td]
end
