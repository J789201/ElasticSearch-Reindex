# ElasticSearch-Reindex
A simple powershell script to help re-index your Elasticsearch indexes

You will require a user account with the relevant privileges to carry out creation and search actions against the cluster/indexes.
The script was tested with a "SuperUser" account and I would recommend you whittle your permissions down as required.

For further reading on index permissions see here - https://www.elastic.co/guide/en/elastic-stack-overview/current/security-privileges.html

The steps to verify the indexes are indeed indexed correctly are left to the user. Once the indexes are verified simply follow the prompts on screen.

### Tested against
Powershell version 5.1 
Elasticsearch version 6.x
