commande pour les recherches scrappeur : 

# Pour les écoles (API gouvernementale, rapide) :
ScrapeOpenDataJob.perform_now(:school, "75")

# Pour tout le reste (Google Maps, lent mais précis) :
ScrapeOpenDataJob.perform_now(:b2b,           "Avocat",          "Lyon")
ScrapeOpenDataJob.perform_now(:b2b,           "Comptable",       "Paris")
ScrapeOpenDataJob.perform_now(:medical,       "Médecin",         "Marseille")
ScrapeOpenDataJob.perform_now(:association,   "Association",     "Bordeaux")
ScrapeOpenDataJob.perform_now(:accommodation, "Hotel",           "Toulouse")
ScrapeOpenDataJob.perform_now(:coach,         "Coach sportif",   "Nantes")
ScrapeOpenDataJob.perform_now(:restaurant, "Restaurant", "Lyon")
