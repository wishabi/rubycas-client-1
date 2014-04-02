module CASClient
  module Tickets
    module Storage

      # A Ticket Store that keeps it's ticket in database tables using ActiveRecord.
      #
      # Services Tickets are stored in an extra column add to the ActiveRecord sessions table.
      # Proxy Granting Tickets and their IOUs are stored in the cas_pgtious table.
      #
      # This ticket store takes the following config parameters
      # :pgtious_table_name - the name of the table 
      class ActiveRecordTicketStore < AbstractTicketStore

        def initialize(config={})
          config ||= {}
          if config[:pgtious_table_name]
            CasPgtiou.set_table_name = config[:pgtious_table_name]
          end
        end

        def store_service_session_lookup(st, controller)
          raise CASException, "No service_ticket specified." unless st
          raise CASException, "No controller specified." unless controller

          st = st.ticket if st.kind_of? ServiceTicket
          session = controller.session
          Rails.logger.info("L4ME: Contents of ST: #{st}")

          session_id = session_id_from_controller(controller)
          Rails.logger.info("L4ME: Session ID: #{session_id}")
          ActiveRecord::SessionStore::Session.update_all(
            %(service_ticket="%s") % st,
            ["session_id=?", session_id]
          )
        end

        def read_service_session_lookup(st)
          raise CASException, "No service_ticket specified." unless st
          st = st.ticket if st.kind_of? ServiceTicket
          session = ActiveRecord::SessionStore::Session.find_by_service_ticket(st)
          session ? session.session_id : nil
        end

        def cleanup_service_session_lookup(st)
          #no cleanup needed for this ticket store
          #we still raise the exception for API compliance
          raise CASException, "No service_ticket specified." unless st
        end

        def save_pgt_iou(pgt_iou, pgt)
          raise CASClient::CASException.new("Invalid pgt_iou") if pgt_iou.nil?
          raise CASClient::CASException.new("Invalid pgt") if pgt.nil?
          pgtiou = CasPgtiou.create(:pgt_iou => pgt_iou, :pgt_id => pgt)
        end

        def retrieve_pgt(pgt_iou)
          raise CASException, "No pgt_iou specified. Cannot retrieve the pgt." unless pgt_iou

          pgtiou = CasPgtiou.find_by_pgt_iou(pgt_iou)

          raise CASException, "Invalid pgt_iou specified. Perhaps this pgt has already been retrieved?" unless pgtiou
          pgt = pgtiou.pgt_id

          pgtiou.destroy

          pgt

        end

      end

      ::ACTIVE_RECORD_TICKET_STORE = ActiveRecordTicketStore

      class CasPgtiou < ActiveRecord::Base
        #t.string :pgt_iou, :null => false
        #t.string :pgt_id, :null => false
        #t.timestamps
      end
    end
  end
end
