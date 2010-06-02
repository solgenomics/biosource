BEGIN;

-- BIOSOURCE SCHEMA or SAMPLE SCHEMA + PROTOCOL SCHEMA
-- biosource schema are tables that store information about every sample in four different (or three tables)
-- biosource.bs_sample, biosource.bs_sample_elements, biosource.bs_sample_dbxref (to store GO terms...) and/or biosource.bs_sample_cvterm 
-- (to store things like normalized, substraction-sustracted pairs for sample_elements, contaminated-contamination groups...)
-- Sample should store from libraries (type: mRNA library) to proteins (type: protein_fraction). It can store a protocol_group_id, so it is possible
-- store from the growth conditions (protocol_type: plant growth conditions) to mRNA extactions.

-- Biosource tables will have the prefix bs_

CREATE SCHEMA biosource;
GRANT USAGE ON SCHEMA biosource TO web_usr;

COMMENT ON SCHEMA biosource IS 'Biosource schema are composed by tables that store data about biological source of the data or other schemas as transcript or expression. It is a combination of the biological origin (samples) and how it was processed (protocol). See specific table comment for more information. The table prefix used is "bs_"';

-- protocol schema or biosource.bs_protocol tables are a group of tables with the function to store any protocol and link with samples... or other tables.
-- A protocol can be something from growth a plant to process a dataset.

CREATE TABLE biosource.bs_protocol (protocol_id SERIAL PRIMARY KEY, protocol_name varchar(250), protocol_type varchar(250), description text, metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX protocol_id_index ON biosource.bs_protocol (protocol_id);
GRANT SELECT ON biosource.bs_protocol TO web_usr;
GRANT SELECT ON biosource.bs_protocol_protocol_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_protocol IS 'biosource.bs_protocol store general information about how something was processed. mRNA extraction is a protocol, but also can be a protocol sequence_assembly or plant growth';


CREATE TABLE biosource.bs_protocol_pub (protocol_pub_id SERIAL PRIMARY KEY, protocol_id int REFERENCES biosource.bs_protocol (protocol_id), pub_id int REFERENCES public.pub (pub_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX protocol_pub_id_index ON biosource.bs_protocol_pub (protocol_pub_id);
GRANT SELECT ON biosource.bs_protocol_pub TO web_usr;
GRANT SELECT ON biosource.bs_protocol_pub_protocol_pub_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_protocol_pub IS 'biosource.bs_protocol_pub is a linker table to associate publications to some protocols';


CREATE TABLE biosource.bs_tool (tool_id SERIAL PRIMARY KEY, tool_name varchar(250), tool_version varchar(10), tool_type varchar(250), tool_description text, tool_weblink text, file_id int REFERENCES metadata.md_files (file_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX tool_id_index ON biosource.bs_tool (tool_id);
GRANT SELECT ON biosource.bs_tool TO web_usr;
GRANT SELECT ON biosource.bs_tool_tool_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_tool IS 'biosource.bs_tool stores information about the tools used during the execution of some protocols. Example of tools are vectors, mRNA purification kits, software, soils. They can have links to web_pages or/and files.';


CREATE TABLE biosource.bs_tool_pub (tool_pub_id SERIAL PRIMARY KEY, tool_id int REFERENCES biosource.bs_tool (tool_id), pub_id int REFERENCES public.pub (pub_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX tool_pub_id_index ON biosource.bs_tool_pub (tool_pub_id);
GRANT SELECT ON biosource.bs_tool_pub TO web_usr;
GRANT SELECT ON biosource.bs_tool_pub_tool_pub_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_tool_pub IS 'biosource.bs_tool_pub is a linker table to associate publications to some tools';


CREATE TABLE biosource.bs_protocol_step (protocol_step_id SERIAL PRIMARY KEY, protocol_id int REFERENCES biosource.bs_protocol (protocol_id), step int, action text, execution text, tool_id int REFERENCES biosource.bs_tool (tool_id), begin_date timestamp, end_date timestamp, location text, metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX protocol_step_id_index ON biosource.bs_protocol_step (protocol_step_id);
GRANT SELECT ON biosource.bs_protocol_step TO web_usr;
GRANT SELECT ON biosource.bs_protocol_step_protocol_step_id_Seq TO web_usr;
COMMENT ON TABLE biosource.bs_protocol_step IS 'biosource.bs_protocol_step store data for each step or stage in a protocol. They are order by the secuencially by step column. Execution describe the action produced during the step, for example plant growth at 24C, blastall -p blastx, ligation... begin_date, end_date and location generally will be used for plant field growth conditions.';


-- To store a controlled vocabulary of each action (growth in a greenhouse could be a environment ontology)

CREATE TABLE biosource.bs_protocol_step_dbxref (protocol_step_dbxref_id SERIAL PRIMARY KEY, protocol_step_id int REFERENCES biosource.bs_protocol_step (protocol_step_id), dbxref_id int REFERENCES public.dbxref (dbxref_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX protocol_step_dbxref_id_index ON biosource.bs_protocol_step_dbxref (protocol_step_dbxref_id);
GRANT SELECT ON biosource.bs_protocol_step_dbxref TO web_usr;
GRANT SELECT ON biosource.bs_protocol_step_dbxref_protocol_step_dbxref_id_seq TO web_usr;  
COMMENT ON TABLE biosource.bs_protocol_step_dbxref IS 'biosource.bs_protocol_step_dbxref is a loker table designed to store controlled vocabulary terms associated to some protocol steps';


-- Things that it should store, for example plant growth conditions in a greenhouse during two months could be stored as:
-- INSERT INTO biosource.bs_protocol (protocol_name, protocol_type, description) VALUES ('Nicotiana tabacum tissue sampling', 'Tissue Sampling', '...');
-- INSERT INTO biosource.bs_protocol_steps (protocol_id, step, action, execution, begin_date, end_date, location) VALUES (1, 1, 'Plant growth in greenhouse',
-- '16h light and 26C', '09-May-2009', '09-Jun-2009', 'Cambridge, UK');
-- INSERT INTO biosource.bs_protocol_steps (protocol_id, step, action, begin_date, end_date, location) VALUES (1, 2, 'Plant tissue sampling, get the two 
-- oldest leaves and store in liquid nitrogene', '', '09-Jun-2009', '', 'Cambridge, UK'); 
-- Other example: Unigene assembly
-- INSERT INTO biosource.bs_protocol (protocol_name, protocol_type, description) VALUES ('SGN Unigene Assembly', 'Software Pipeline', '...');
-- INSERT INTO biosource.bs_portocol_steps (protocol_id, step, action, execution, tool_id) VALUES (1, 1, 'Unigene Assembly using MIRA', 
-- 'mira -project=nt_genome_atc06 -fasta -job=denovo,genome,normal,454 -highlyrepetitive -AS:nop=2 -GE:not=6 -SK:not=6:mnr=yes:nrr=8',
-- (SELECT tool_id FROM biosource.bs_tool WHERE tool_name = 'MIRA' AND tool_version = '3.0'));



CREATE TABLE biosource.bs_sample (sample_id SERIAL PRIMARY KEY, sample_name varchar(250), sample_type varchar(250), description text, contact_id int REFERENCES sgn_people.sp_person (sp_person_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_id_index ON biosource.bs_sample (sample_id);
GRANT SELECT ON biosource.bs_sample TO web_usr;
GRANT SELECT ON biosource.bs_sample_sample_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample IS 'biosource.bs_sample store information about the origin of a biological sample. It can be composed by different elements, for example tomato fruit sample can be a mix of fruits in different stages. Each stage will be a sample_element. Sample also can have associated a sp_person_id in terms of contact.';


-- This is a linker table between samples and publications
CREATE TABLE biosource.bs_sample_pub (sample_pub_id SERIAL PRIMARY KEY, sample_id int REFERENCES biosource.bs_sample (sample_id), pub_id int REFERENCES public.pub (pub_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_pub_id_index ON biosource.bs_sample_pub (sample_pub_id);
GRANT SELECT ON biosource.bs_sample_pub TO web_usr;
GRANT SELECT ON biosource.bs_sample_pub_sample_pub_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_pub IS 'bisource.bs_sample_pub is a linker table to associate publications to a sample.';


-- This table has a link to organism 
CREATE TABLE biosource.bs_sample_element (sample_element_id SERIAL PRIMARY KEY, sample_element_name varchar(250), alternative_name text, sample_id int REFERENCES biosource.bs_sample (sample_id), description text, organism_id int REFERENCES public.organism (organism_id), stock_id int, protocol_id int REFERENCES biosource.bs_protocol (protocol_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_element_id_index ON biosource.bs_sample_element (sample_element_id);
GRANT SELECT ON biosource.bs_sample_element TO web_usr;
GRANT SELECT ON biosource.bs_sample_element_sample_element_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_element IS 'biosource.bs_sample_element store information of each elemennt of a sample. It have a organism_id column and stock_id to associate different origins, for example a tomato leaves sample can be composed by leaves of Solanum lycopersicum and Solanum pimpinellifolium.';


-- This table store relations to cvterm to add tags to the samples as 'Normalized', 'Sustracted'-'Sustractor'...
CREATE TABLE biosource.bs_sample_element_cvterm (sample_element_cvterm_id SERIAL PRIMARY KEY, sample_element_id int REFERENCES biosource.bs_sample_element (sample_element_id), cvterm_id int REFERENCES public.cvterm (cvterm_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_element_cvterm_id_index ON biosource.bs_sample_element_cvterm (sample_element_cvterm_id);
GRANT SELECT ON biosource.bs_sample_element_cvterm TO web_usr;
GRANT select ON biosource.bs_sample_element_cvterm_sample_element_cvterm_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_element_cvterm IS 'biosource.bs_sample_cvterm is a linker table to associate tags to the samples as Normalized, Sustracted...';


-- This table should store the description of the sample as PO terms
CREATE TABLE biosource.bs_sample_element_dbxref (sample_element_dbxref_id SERIAL PRIMARY KEY, sample_element_id int REFERENCES biosource.bs_sample_element (sample_element_id), dbxref_id bigint REFERENCES public.dbxref (dbxref_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_element_dbxref_id_index ON biosource.bs_sample_element_dbxref (sample_element_dbxref_id);
GRANT SELECT ON biosource.bs_sample_element_dbxref TO web_usr;
GRANT select ON biosource.bs_sample_element_dbxref_sample_element_dbxref_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_element_dbxref IS 'biosource.bs_sample_element_dbxref is a linker table to associate controlled vocabullary as Plant Ontology to each element of a sample';


-- Example of samples:
-- Library... has the following colums: type (biosource.bs_sample.sample_type), submit_user_id (metadata.md_metadata.create_person_id), 
--    library_name (biosource.bs_sample_elements.alternative_name), library_shortname (biosource.bs_sample_elements.sample_element_name), 
--    authors (biosource.bs_sample.pub_group_id), organism_id AND cultivar AND accession (biosource.bs_sample_elements.stock_id)          
--    tissue AND development_stage (biosource.bs_sample_element_dbxref), treatment_conditions AND cloning_host AND vector AND rs1 AND rs2 
--    AND cloning_kit (biosource.bs_sample_elements.protocol_id), comments (biosource.bs_sample.description), contact_information (biosource.bs_sample.contact_person_id),
--    order_routing_id (?) ,sp_person_id (biosource.bs_sample.metadata_id),forward_adapter AND reverse_adapter (biosource.bs_sample_elements.protocol_id),
--    obsolete AND modified_date AND create_date (biosource.bs_sample_elements.metadata_id)

ROLLBACK;
