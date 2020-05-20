def discovery_id(nypl_source, id)
  prefix = {
    "recap-cul" => "cb",
    "recap-pul" => "pb",
    "sierra-nypl" => "b",
  }[nypl_source]

  prefix + id
end

def nypl_sources
  ["sierra-nypl", "recap-pul", "recap-cul"]
end

def parse_tagged_subject_headings(data)

end
