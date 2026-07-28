from backfill_place_coords import coords_from_entity


def test_reads_p625_from_entity():
    entity = {
        "claims": {
            "P625": [
                {
                    "mainsnak": {
                        "datavalue": {
                            "value": {"latitude": 41.9022, "longitude": 12.4539}
                        }
                    }
                }
            ]
        }
    }
    assert coords_from_entity(entity) == (41.9022, 12.4539)


def test_returns_none_when_no_p625():
    assert coords_from_entity({"claims": {}}) is None


def test_returns_none_when_claim_is_malformed():
    entity = {"claims": {"P625": [{"mainsnak": {"snaktype": "novalue"}}]}}
    assert coords_from_entity(entity) is None
